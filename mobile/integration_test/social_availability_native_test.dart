import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shobuj_mobile/services/social_sign_in_service.dart';

/// On the simulator: the native Info.plist check answers, and Google stays
/// hidden until its URL scheme is registered.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('availability on iPhone', (tester) async {
    final schemes = await const MethodChannel(
      'shobuj/app_info',
    ).invokeListMethod<String>('urlSchemes');
    expect(schemes, isNotNull);

    final available = await SocialSignInService().availableProviders(
      const SocialConfig(
        googleEnabled: true,
        googleIosClientId: '123-notregistered.apps.googleusercontent.com',
        appleEnabled: true,
      ),
    );
    expect(available, [SocialProvider.apple]);

    expect(
      await SocialSignInService().availableProviders(SocialConfig.off),
      isEmpty,
    );
  });
}
