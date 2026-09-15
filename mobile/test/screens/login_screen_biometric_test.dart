import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/auth/login_screen.dart';
import 'package:shobuj_mobile/services/api_client.dart';

import '../support/fake_api_client.dart';
import '../support/fake_biometric_service.dart';
import '../support/fake_secure_storage_service.dart';

void main() {
  testWidgets('the biometric button is hidden when no credentials are saved', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(FakeApiClient()),
          secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
          biometricServiceProvider.overrideWithValue(FakeBiometricService()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in with Face ID / Fingerprint'), findsNothing);
  });

  testWidgets(
    'the biometric button is hidden when the device does not support it, '
    'even with saved credentials',
    (tester) async {
      final fakeStorage = FakeSecureStorageService();
      await fakeStorage.saveBiometricCredentials(
        email: 'rina@example.com',
        password: 'password123',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeApiClient()),
            secureStorageProvider.overrideWithValue(fakeStorage),
            biometricServiceProvider.overrideWithValue(
              FakeBiometricService(available: false),
            ),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sign in with Face ID / Fingerprint'), findsNothing);
    },
  );

  testWidgets(
    'tapping the biometric button authenticates and signs in with the '
    'saved credentials',
    (tester) async {
      final fakeStorage = FakeSecureStorageService();
      await fakeStorage.saveBiometricCredentials(
        email: 'rina@example.com',
        password: 'password123',
      );
      final fakeBiometrics = FakeBiometricService();
      final fakeClient = FakeApiClient()
        ..loginResult = AuthResult(
          user: buildFakeUser(name: 'Rina'),
          token: 'biometric-token',
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            secureStorageProvider.overrideWithValue(fakeStorage),
            biometricServiceProvider.overrideWithValue(fakeBiometrics),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final biometricButton = find.text('Sign in with Face ID / Fingerprint');
      expect(biometricButton, findsOneWidget);

      await tester.ensureVisible(biometricButton);
      await tester.tap(biometricButton);
      await tester.pumpAndSettle();

      expect(fakeBiometrics.authenticateCalled, isTrue);
      expect(await fakeStorage.readToken(), 'biometric-token');
    },
  );

  testWidgets(
    'a declined biometric prompt shows an error and does not sign in',
    (tester) async {
      final fakeStorage = FakeSecureStorageService();
      await fakeStorage.saveBiometricCredentials(
        email: 'rina@example.com',
        password: 'password123',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(FakeApiClient()),
            secureStorageProvider.overrideWithValue(fakeStorage),
            biometricServiceProvider.overrideWithValue(
              FakeBiometricService(authenticateSucceeds: false),
            ),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      final biometricButton = find.text('Sign in with Face ID / Fingerprint');
      await tester.ensureVisible(biometricButton);
      await tester.tap(biometricButton);
      await tester.pumpAndSettle();

      expect(
        find.text("Couldn't verify — try again or use your password."),
        findsOneWidget,
      );
      expect(await fakeStorage.readToken(), isNull);
    },
  );

  testWidgets(
    'logging in with "Remember me" checked saves biometric credentials',
    (tester) async {
      final fakeStorage = FakeSecureStorageService();
      final fakeClient = FakeApiClient()
        ..loginResult = AuthResult(
          user: buildFakeUser(name: 'Rina'),
          token: 'new-token',
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            secureStorageProvider.overrideWithValue(fakeStorage),
            biometricServiceProvider.overrideWithValue(FakeBiometricService()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // "Remember me" defaults to checked.
      await tester.enterText(
        find.byKey(const Key('login-email-field')),
        'rina@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login-password-field')),
        'password123',
      );
      final signInButton = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInButton);
      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      final saved = await fakeStorage.readBiometricCredentials();
      expect(saved?.email, 'rina@example.com');
      expect(saved?.password, 'password123');
    },
  );

  testWidgets(
    'unchecking "Remember me" clears any saved biometric credentials',
    (tester) async {
      final fakeStorage = FakeSecureStorageService();
      await fakeStorage.saveBiometricCredentials(
        email: 'old@example.com',
        password: 'old-password',
      );
      final fakeClient = FakeApiClient()
        ..loginResult = AuthResult(
          user: buildFakeUser(name: 'Rina'),
          token: 'new-token',
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            secureStorageProvider.overrideWithValue(fakeStorage),
            biometricServiceProvider.overrideWithValue(FakeBiometricService()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('login-email-field')),
        'rina@example.com',
      );
      await tester.enterText(
        find.byKey(const Key('login-password-field')),
        'password123',
      );
      await tester.pumpAndSettle();

      final signInButton = find.widgetWithText(FilledButton, 'Sign In');
      await tester.ensureVisible(signInButton);
      await tester.pumpAndSettle();
      await tester.tap(signInButton, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(await fakeStorage.readBiometricCredentials(), isNull);
    },
  );
}
