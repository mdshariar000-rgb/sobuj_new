import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/geo_point.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/location_providers.dart';
import 'package:shobuj_mobile/screens/auth/login_screen.dart';
import 'package:shobuj_mobile/screens/auth/register_screen.dart';
import 'package:shobuj_mobile/services/api_exception.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

const _fakeLocation = GeoPoint(latitude: 53.8173, longitude: -1.5776);

void main() {
  Future<void> pumpLoginScreen(
    WidgetTester tester,
    FakeApiClient fakeClient,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows validation errors for empty fields', (tester) async {
    await pumpLoginScreen(tester, FakeApiClient());

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pump();

    expect(find.text('Enter your email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('shows the server error message when login fails', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..loginError = const ApiException(
        message: 'The provided credentials are incorrect.',
        statusCode: 422,
      );

    await pumpLoginScreen(tester, fakeClient);

    await tester.enterText(
      find.byKey(const Key('login-email-field')),
      'rina@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'wrong-password',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(
      find.text('The provided credentials are incorrect.'),
      findsOneWidget,
    );
  });

  testWidgets('a suspended-account message from the backend is shown as-is', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..loginError = const ApiException(
        message:
            'This account has been suspended: Repeated banned-species listings',
        statusCode: 403,
      );

    await pumpLoginScreen(tester, fakeClient);

    await tester.enterText(
      find.byKey(const Key('login-email-field')),
      'rina@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'password123',
    );
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This account has been suspended: Repeated banned-species listings',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping "Don\'t have an account? Register / Sign Up" navigates to the Register screen',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeApiClient()),
            secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
            // RegisterScreen's location indicator has an indefinite spinner while
            // loading, which would otherwise never let pumpAndSettle() finish.
            accountLocationProvider.overrideWith((ref) async => _fakeLocation),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final signUpLink = find.text("Don't have an account? Register / Sign Up");
      await tester.ensureVisible(signUpLink);
      await tester.tap(signUpLink);
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
    },
  );
}
