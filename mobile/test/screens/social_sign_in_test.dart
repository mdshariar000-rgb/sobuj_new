import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/geo_point.dart';
import 'package:shobuj_mobile/models/uk_address.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/location_providers.dart';
import 'package:shobuj_mobile/screens/auth/auth_gate.dart';
import 'package:shobuj_mobile/screens/auth/login_screen.dart';
import 'package:shobuj_mobile/screens/auth/social_signup_screen.dart';
import 'package:shobuj_mobile/screens/onboarding/onboarding_screen.dart';
import 'package:shobuj_mobile/screens/profile/privacy_safety_screen.dart';
import 'package:shobuj_mobile/screens/shell/agro_hub_shell.dart';
import 'package:shobuj_mobile/services/api_client.dart';
import 'package:shobuj_mobile/services/api_exception.dart';
import 'package:shobuj_mobile/services/social_sign_in_service.dart';
import 'package:shobuj_mobile/theme/app_theme.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';
import '../support/fake_social_sign_in_service.dart';
import '../support/fake_uk_location_service.dart';

const _googleCredential = SocialCredential(
  provider: SocialProvider.google,
  idToken: 'google-id-token',
  name: 'Rina Akter',
);

Future<FakeSecureStorageService> _pumpGate(
  WidgetTester tester, {
  required FakeApiClient client,
  required FakeSocialSignInService social,
  Widget home = const AuthGate(),
  bool signedIn = false,
}) async {
  final storage = FakeSecureStorageService();
  if (signedIn) await storage.saveToken('existing-token');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        secureStorageProvider.overrideWithValue(storage),
        socialSignInServiceProvider.overrideWithValue(social),
        ukLocationServiceProvider.overrideWithValue(FakeUkLocationService()),
        accountLocationProvider.overrideWith(
          (ref) async => const GeoPoint(latitude: 53.8, longitude: -1.5),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: home),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}

Future<void> _tapGoogle(WidgetTester tester) async {
  final button = find.byKey(const Key('social-google-button'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the buttons stay hidden where neither provider is available', (
    tester,
  ) async {
    await _pumpGate(
      tester,
      client: FakeApiClient(),
      social: FakeSocialSignInService(google: false, apple: false),
    );

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('OR CONTINUE WITH'), findsNothing);
    expect(find.byKey(const Key('social-google-button')), findsNothing);
  });

  testWidgets('an existing account signs straight in with Google', (
    tester,
  ) async {
    final client = FakeApiClient()
      ..socialLoginResult = SocialSignedIn(
        AuthResult(user: buildFakeUser(), token: 'social-token'),
        isNewUser: false,
      );
    final storage = await _pumpGate(
      tester,
      client: client,
      social: FakeSocialSignInService(credential: _googleCredential),
    );

    await _tapGoogle(tester);

    expect(client.socialLoginCalls.single['provider'], 'google');
    expect(client.socialLoginCalls.single['idToken'], 'google-id-token');
    expect(await storage.readToken(), 'social-token');
    expect(find.byType(AgroHubShell), findsOneWidget);
  });

  testWidgets('cancelling the Google sheet does nothing', (tester) async {
    final client = FakeApiClient();
    await _pumpGate(tester, client: client, social: FakeSocialSignInService());

    await _tapGoogle(tester);

    expect(client.socialLoginCalls, isEmpty);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('a provider error is shown', (tester) async {
    await _pumpGate(
      tester,
      client: FakeApiClient(),
      social: FakeSocialSignInService(
        error: const SocialSignInException(
          "Google sign-in didn't work. Please try again.",
        ),
      ),
    );

    await _tapGoogle(tester);

    expect(
      find.text("Google sign-in didn't work. Please try again."),
      findsOneWidget,
    );
  });

  testWidgets('someone new finishes signing up with their address, then '
      'sees onboarding', (tester) async {
    final client = FakeApiClient()
      ..socialLoginResult = const SocialNeedsSignup(
        email: 'rina@example.com',
        name: 'Rina Akter',
      )
      ..socialSignupResult = AuthResult(
        user: buildFakeUser(),
        token: 'new-social-token',
      );
    final storage = await _pumpGate(
      tester,
      client: client,
      social: FakeSocialSignInService(credential: _googleCredential),
    );

    await _tapGoogle(tester);

    expect(find.byType(SocialSignupScreen), findsOneWidget);
    expect(find.text('rina@example.com'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('social-signup-name')))
          .controller
          ?.text,
      'Rina Akter',
    );

    await tester.enterText(
      find.byKey(const Key('address-postcode-field')),
      'ls6 3aa',
    );
    await tester.tap(find.byKey(const Key('address-find-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('address-line1-field')),
      '12 Cardigan Road',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('social-signup-submit')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SocialSignupScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('social-signup-terms')));
    await tester.tap(find.byKey(const Key('social-signup-submit')));
    await tester.pumpAndSettle();

    final signup = client.socialLoginCalls.last;
    expect(signup['name'], 'Rina Akter');
    expect((signup['address'] as UkAddress).postcode, 'LS6 3AA');
    expect((signup['address'] as UkAddress).line1, '12 Cardigan Road');
    expect(signup['latitude'], isNotNull);
    expect(await storage.readToken(), 'new-social-token');
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('finishing sign-up needs the terms agreed', (tester) async {
    final client = FakeApiClient()
      ..socialLoginResult = const SocialNeedsSignup(email: 'rina@example.com');
    await _pumpGate(
      tester,
      client: client,
      social: FakeSocialSignInService(credential: _googleCredential),
    );
    await _tapGoogle(tester);

    await tester.enterText(
      find.byKey(const Key('address-postcode-field')),
      'ls6 3aa',
    );
    await tester.tap(find.byKey(const Key('address-find-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('address-line1-field')),
      '12 Cardigan Road',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('social-signup-submit')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SocialSignupScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('social-signup-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Please agree to the terms to continue.'), findsOneWidget);
    expect(client.socialLoginCalls, hasLength(1));
  });

  testWidgets('an account with no password confirms deletion with Google', (
    tester,
  ) async {
    final client = FakeApiClient()
      ..meResult = buildFakeUser(hasPassword: false, signedInWith: ['google']);
    final social = FakeSocialSignInService(credential: _googleCredential);
    await _pumpGate(
      tester,
      client: client,
      social: social,
      signedIn: true,
      home: const PrivacySafetyScreen(),
    );

    await tester.scrollUntilVisible(
      find.text('Delete account'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('delete-account-password')), findsNothing);
    expect(find.text('To confirm, sign in with Google again.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-account-confirm')));
    await tester.pumpAndSettle();

    expect(social.requested, [SocialProvider.google]);
    expect(client.lastDeletedAccountToken?.provider, 'google');
    expect(client.lastDeletedAccountToken?.idToken, 'google-id-token');
    expect(client.lastDeletedAccountPassword, isNull);
  });

  testWidgets('a rejected sign-in token shows the server message', (
    tester,
  ) async {
    await _pumpGate(
      tester,
      client: FakeApiClient()
        ..socialLoginError = const ApiException(
          message: 'That sign-in was for a different app.',
          statusCode: 401,
        ),
      social: FakeSocialSignInService(credential: _googleCredential),
    );

    await _tapGoogle(tester);

    expect(find.text('That sign-in was for a different app.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  test('the admin panel settings are read from the server', () {
    final config = SocialConfig.fromJson({
      'google': {
        'enabled': true,
        'ios_client_id': 'ios.apps.googleusercontent.com',
        'server_client_id': 'web.apps.googleusercontent.com',
      },
      'apple': {'enabled': false},
    });

    expect(config.googleEnabled, isTrue);
    expect(config.googleIosClientId, 'ios.apps.googleusercontent.com');
    expect(config.googleServerClientId, 'web.apps.googleusercontent.com');
    expect(config.appleEnabled, isFalse);
    expect(SocialConfig.fromJson(const {}).googleEnabled, isFalse);
  });

  testWidgets('deleting an Apple account sends Apple\'s one-time code so '
      'the server can unlink it', (tester) async {
    final client = FakeApiClient()
      ..meResult = buildFakeUser(hasPassword: false, signedInWith: ['apple']);
    final social = FakeSocialSignInService(
      credential: const SocialCredential(
        provider: SocialProvider.apple,
        idToken: 'apple-id-token',
        nonce: 'raw-nonce',
        authorizationCode: 'apple-code',
      ),
    );
    await _pumpGate(
      tester,
      client: client,
      social: social,
      signedIn: true,
      home: const PrivacySafetyScreen(),
    );

    await tester.scrollUntilVisible(
      find.text('Delete account'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account-confirm')));
    await tester.pumpAndSettle();

    expect(client.lastDeletedAccountToken?.provider, 'apple');
    expect(client.lastDeletedAccountToken?.nonce, 'raw-nonce');
    expect(client.lastDeletedAccountToken?.code, 'apple-code');
  });
}
