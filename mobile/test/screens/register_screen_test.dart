import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/location_providers.dart';
import 'package:shobuj_mobile/screens/auth/auth_gate.dart';
import 'package:shobuj_mobile/screens/auth/register_screen.dart';
import 'package:shobuj_mobile/screens/shell/agro_hub_shell.dart';
import 'package:shobuj_mobile/services/api_client.dart';
import 'package:shobuj_mobile/services/api_exception.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

final _fakePosition = Position(
  latitude: 23.780636,
  longitude: 90.279785,
  timestamp: DateTime(2026, 1, 1),
  accuracy: 5,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

const _submitButton = Key('register-submit-button');

Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('register-name-field')), 'Rina');
  await tester.enterText(
    find.byKey(const Key('register-email-field')),
    'rina@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('register-password-field')),
    'password123',
  );
  await tester.enterText(
    find.byKey(const Key('register-confirm-password-field')),
    'password123',
  );
  await tester.ensureVisible(find.byKey(const Key('register-terms-checkbox')));
  await tester.tap(find.byKey(const Key('register-terms-checkbox')));
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(_submitButton));
  await tester.tap(find.byKey(_submitButton));
}

void main() {
  testWidgets(
    'blocks submission and explains why when location is unavailable',
    (tester) async {
      final fakeClient = FakeApiClient();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
            deviceLocationProvider.overrideWith(
              (ref) async => throw const LocationPermissionDeniedException(),
            ),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('We need your location'), findsOneWidget);
      expect(
        fakeClient.registerResult,
        isNull,
      ); // register() was never even configured/called
    },
  );

  testWidgets('shows a validation error when passwords do not match', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(FakeApiClient()),
          secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
          deviceLocationProvider.overrideWith((ref) async => _fakePosition),
        ],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('register-name-field')),
      'Rina',
    );
    await tester.enterText(
      find.byKey(const Key('register-email-field')),
      'rina@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password-field')),
      'password123',
    );
    await tester.enterText(
      find.byKey(const Key('register-confirm-password-field')),
      'different',
    );
    await _tapSubmit(tester);
    await tester.pump();

    expect(find.text('Passwords do not match.'), findsOneWidget);
  });

  testWidgets('shows a validation error when the password is too short', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(FakeApiClient()),
          secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
          deviceLocationProvider.overrideWith((ref) async => _fakePosition),
        ],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('register-name-field')),
      'Rina',
    );
    await tester.enterText(
      find.byKey(const Key('register-email-field')),
      'rina@example.com',
    );
    await tester.enterText(
      find.byKey(const Key('register-password-field')),
      'short',
    );
    await tester.enterText(
      find.byKey(const Key('register-confirm-password-field')),
      'short',
    );
    await _tapSubmit(tester);
    await tester.pump();

    expect(
      find.text('Password must be at least 8 characters.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'blocks submission and explains why when the terms are not agreed to',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeApiClient()),
            secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
            deviceLocationProvider.overrideWith((ref) async => _fakePosition),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Fill everything except agreeing to the terms checkbox.
      await tester.enterText(
        find.byKey(const Key('register-name-field')),
        'Rina',
      );
      await tester.enterText(
        find.byKey(const Key('register-email-field')),
        'rina@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('register-password-field')),
        'password123',
      );
      await tester.enterText(
        find.byKey(const Key('register-confirm-password-field')),
        'password123',
      );
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('agree to the terms'), findsOneWidget);
    },
  );

  testWidgets(
    'maps a server-side field validation error onto the matching field',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..registerError = const ApiException(
          message: 'The email has already been taken.',
          statusCode: 422,
          fieldErrors: {
            'email': ['The email has already been taken.'],
          },
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
            deviceLocationProvider.overrideWith((ref) async => _fakePosition),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('The email has already been taken.'), findsWidgets);
    },
  );

  testWidgets(
    'a successful registration automatically swaps to the Agro Hub shell',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..registerResult = AuthResult(
          user: buildFakeUser(),
          token: 'new-token',
        );
      final fakeStorage = FakeSecureStorageService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            secureStorageProvider.overrideWithValue(fakeStorage),
            deviceLocationProvider.overrideWith((ref) async => _fakePosition),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      // AuthGate starts on the Login screen; navigate to Register first.
      final signUpLink = find.text("Don't have an account? Register / Sign Up");
      await tester.ensureVisible(signUpLink);
      await tester.tap(signUpLink);
      await tester.pumpAndSettle();

      await _fillValidForm(tester);
      await _tapSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.byType(AgroHubShell), findsOneWidget);
      expect(await fakeStorage.readToken(), 'new-token');
    },
  );
}
