import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/geo_point.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/location_providers.dart';
import 'package:shobuj_mobile/screens/auth/auth_gate.dart';
import 'package:shobuj_mobile/screens/auth/login_screen.dart';
import 'package:shobuj_mobile/screens/shell/agro_hub_shell.dart';
import 'package:shobuj_mobile/services/api_client.dart';
import 'package:shobuj_mobile/services/api_exception.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

const _fakeLocation = GeoPoint(latitude: 53.8173, longitude: -1.5776);

void main() {
  testWidgets('with no stored session, shows the login screen', (tester) async {
    final fakeClient = FakeApiClient();
    final fakeStorage = FakeSecureStorageService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          secureStorageProvider.overrideWithValue(fakeStorage),
        ],
        child: const MaterialApp(home: AuthGate()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AgroHubShell), findsNothing);
  });

  testWidgets(
    'a successful login automatically swaps to the Agro Hub shell (no manual navigation)',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..loginResult = AuthResult(user: buildFakeUser(), token: 'new-token');
      final fakeStorage = FakeSecureStorageService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            secureStorageProvider.overrideWithValue(fakeStorage),
            accountLocationProvider.overrideWith((ref) async => _fakeLocation),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

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

      expect(find.byType(AgroHubShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(await fakeStorage.readToken(), 'new-token');
    },
  );

  testWidgets(
    'logging out from Profile (reached via the header avatar) swaps back '
    'to the login screen',
    (tester) async {
      final fakeClient = FakeApiClient()..meResult = buildFakeUser();
      final fakeStorage = FakeSecureStorageService();
      await fakeStorage.saveToken('existing-token');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            secureStorageProvider.overrideWithValue(fakeStorage),
            accountLocationProvider.overrideWith((ref) async => _fakeLocation),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AgroHubShell), findsOneWidget);

      // Profile now lives behind the Home header's avatar, not a bottom-nav
      // tab (Marketplace/Discovery took that 5th slot).
      await tester.tap(find.byKey(const Key('profile-avatar-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Log out'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await fakeStorage.readToken(), isNull);
      expect(fakeClient.logoutCalled, isTrue);
    },
  );

  testWidgets(
    'a stored token that the server rejects falls back to the login screen',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..meError = const ApiException(
          message: 'Unauthenticated.',
          statusCode: 401,
        );
      final fakeStorage = FakeSecureStorageService();
      await fakeStorage.saveToken('stale-token');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            secureStorageProvider.overrideWithValue(fakeStorage),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(await fakeStorage.readToken(), isNull);
    },
  );
}
