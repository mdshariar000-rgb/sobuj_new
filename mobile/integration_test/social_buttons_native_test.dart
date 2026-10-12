import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/auth/login_screen.dart';
import 'package:shobuj_mobile/services/social_sign_in_service.dart';
import 'package:shobuj_mobile/theme/app_theme.dart';

import '../test/support/fake_api_client.dart';
import '../test/support/fake_secure_storage_service.dart';

/// The Log In screen with the real Google/Apple sign-in plugins on the
/// simulator (API faked, nothing signed in). Taps Apple to show the native
/// sheet. Prints `SHOT <name>` for outside screenshots.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 250; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('social buttons on the device', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(
            FakeApiClient()
              ..socialConfigResult = const SocialConfig(appleEnabled: true),
          ),
          secureStorageProvider.overrideWithValue(FakeSecureStorageService()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const LoginScreen()),
      ),
    );
    await settle(tester, 2000);
    await tester.scrollUntilVisible(
      find.byKey(const Key('social-apple-button')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, 500);
    // ignore: avoid_print
    print('SHOT 20-login-social-buttons');
    await settle(tester, 3000);

    await tester.tap(find.byKey(const Key('social-apple-button')));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    // ignore: avoid_print
    print('SHOT 21-apple-native-sheet');
    // Leave time for the screenshot; the sheet stays until cancelled.
    await Future<void>.delayed(const Duration(seconds: 5));
  });
}
