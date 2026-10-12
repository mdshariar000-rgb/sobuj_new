import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/geo_point.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/location_providers.dart';
import 'package:shobuj_mobile/screens/auth/auth_gate.dart';
import 'package:shobuj_mobile/screens/auth/register_screen.dart';
import 'package:shobuj_mobile/screens/onboarding/onboarding_screen.dart';
import 'package:shobuj_mobile/screens/shell/agro_hub_shell.dart';
import 'package:shobuj_mobile/services/api_client.dart';
import 'package:shobuj_mobile/services/api_exception.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';
import '../support/fake_uk_location_service.dart';

const _fakeLocation = GeoPoint(latitude: 53.8173, longitude: -1.5776);

const _submitButton = Key('register-submit-button');

/// Fills the address form — 'Head' uses a Leeds postcode, 'Card' a Cardiff
/// one (see FakeUkLocationService.postcodes).
Future<void> _selectLocation(WidgetTester tester, String query) async {
  final postcode = query == 'Card' ? 'cf10 1aa' : 'ls6 3aa';
  Future<void> type(String key, String text) async {
    final field = find.byKey(Key(key));
    await tester.ensureVisible(field);
    await tester.enterText(field, text);
  }

  await type('address-postcode-field', postcode);
  // Lookups aren't set up in the fake, so Find opens the lines to type.
  await tester.ensureVisible(find.byKey(const Key('address-find-button')));
  await tester.tap(find.byKey(const Key('address-find-button')));
  await tester.pumpAndSettle();
  await type('address-line1-field', '12 Cardigan Road');
  await type('address-city-field', query == 'Card' ? 'Cardiff' : 'Leeds');
  await tester.pumpAndSettle();
}

Future<void> _fillValidForm(
  WidgetTester tester, {
  String location = 'Head',
}) async {
  await _selectLocation(tester, location);
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
  testWidgets('blocks submission until the address is filled in', (
    tester,
  ) async {
    final fakeClient = FakeApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          ukLocationServiceProvider.overrideWithValue(FakeUkLocationService()),
          secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
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
      'password123',
    );
    await tester.ensureVisible(
      find.byKey(const Key('register-terms-checkbox')),
    );
    await tester.tap(find.byKey(const Key('register-terms-checkbox')));
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a full UK postcode, e.g. LS6 3AA.'),
      findsOneWidget,
    );
    // Only the postcode is asked for up front; the lines come from it.
    expect(find.byKey(const Key('address-line1-field')), findsNothing);
    expect(fakeClient.lastRegisterLocationLabel, isNull);
  });

  testWidgets('the full address is sent, and an unknown postcode is caught', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..registerResult = AuthResult(user: buildFakeUser(), token: 'new-token');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          ukLocationServiceProvider.overrideWithValue(FakeUkLocationService()),
          secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
        ],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await _fillValidForm(tester);
    await tester.enterText(
      find.byKey(const Key('address-postcode-field')),
      'ZZ9 9ZZ',
    );
    await tester.pumpAndSettle();
    await _tapSubmit(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining("couldn't find that postcode"), findsOneWidget);
    expect(fakeClient.lastRegisterAddress, isNull);

    await tester.enterText(
      find.byKey(const Key('address-postcode-field')),
      'ls6 3aa',
    );
    await tester.pumpAndSettle();
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    final address = fakeClient.lastRegisterAddress!;
    expect(address.line1, '12 Cardigan Road');
    expect(address.city, 'Leeds');
    expect(address.postcode, 'LS6 3AA');
    expect(fakeClient.lastRegisterLocationLabel, 'Headingley, Leeds, England');
  });

  testWidgets('shows a validation error when passwords do not match', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(FakeApiClient()),
          ukLocationServiceProvider.overrideWithValue(FakeUkLocationService()),
          secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
          accountLocationProvider.overrideWith((ref) async => _fakeLocation),
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
          ukLocationServiceProvider.overrideWithValue(FakeUkLocationService()),
          secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
          accountLocationProvider.overrideWith((ref) async => _fakeLocation),
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
            ukLocationServiceProvider.overrideWithValue(
              FakeUkLocationService(),
            ),
            secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
            accountLocationProvider.overrideWith((ref) async => _fakeLocation),
          ],
          child: const MaterialApp(home: RegisterScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Fill everything except agreeing to the terms checkbox.
      await _selectLocation(tester, 'Head');
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
            ukLocationServiceProvider.overrideWithValue(
              FakeUkLocationService(),
            ),
            secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
            accountLocationProvider.overrideWith((ref) async => _fakeLocation),
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
    'a successful registration goes through onboarding, then to the Agro Hub shell',
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
            ukLocationServiceProvider.overrideWithValue(
              FakeUkLocationService(),
            ),
            secureStorageProvider.overrideWithValue(fakeStorage),
            accountLocationProvider.overrideWith((ref) async => _fakeLocation),
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

      // A brand-new account sees onboarding first, never Home.
      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(AgroHubShell), findsNothing);
      expect(await fakeStorage.readToken(), 'new-token');

      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(find.byType(AgroHubShell), findsOneWidget);
    },
  );

  testWidgets('the selected UK location is sent as the registration location', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..registerResult = AuthResult(user: buildFakeUser(), token: 'new-token');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          ukLocationServiceProvider.overrideWithValue(FakeUkLocationService()),
          secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
        ],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await _fillValidForm(tester, location: 'Card');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(fakeClient.lastRegisterLocationLabel, 'Cardiff, Wales');
  });

  testWidgets('picked interests are sent with the registration', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..registerResult = AuthResult(user: buildFakeUser(), token: 'new-token');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          ukLocationServiceProvider.overrideWithValue(FakeUkLocationService()),
          secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
        ],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();

    for (final interest in ['Seller', 'Sustainability']) {
      final chip = find.byKey(Key('interest-$interest'));
      await tester.ensureVisible(chip);
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    expect(find.text('Allotment'), findsOneWidget);
    await _fillValidForm(tester, location: 'Card');
    await _tapSubmit(tester);
    await tester.pumpAndSettle();

    expect(fakeClient.lastRegisterInterests, ['Seller', 'Sustainability']);
  });
}
