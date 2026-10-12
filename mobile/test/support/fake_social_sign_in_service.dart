import 'package:shobuj_mobile/services/social_sign_in_service.dart';

/// Pretends Google and Apple are available and hands back [credential]
/// (null acts like the user cancelling).
class FakeSocialSignInService extends SocialSignInService {
  FakeSocialSignInService({
    this.google = true,
    this.apple = true,
    this.credential,
    this.error,
  });

  final bool google;
  final bool apple;
  SocialCredential? credential;
  SocialSignInException? error;
  final requested = <SocialProvider>[];

  @override
  Future<List<SocialProvider>> availableProviders(SocialConfig config) async =>
      [if (apple) SocialProvider.apple, if (google) SocialProvider.google];

  @override
  Future<SocialCredential?> signIn(
    SocialProvider provider,
    SocialConfig config,
  ) async {
    requested.add(provider);
    if (error != null) throw error!;
    return credential;
  }
}
