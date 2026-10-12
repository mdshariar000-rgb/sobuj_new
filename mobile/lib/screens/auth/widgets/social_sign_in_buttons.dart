import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../services/api_exception.dart';
import '../../../services/social_sign_in_service.dart';
import '../../../theme/app_colors.dart';
import '../social_signup_screen.dart';

/// "Continue with Google" / "Sign in with Apple", for Log In and Create
/// Account. A known account signs straight in; a new person goes on to
/// [SocialSignupScreen] for the address. Hidden entirely when neither is
/// available (Google not set up, Apple not on this platform).
class SocialSignInButtons extends ConsumerStatefulWidget {
  const SocialSignInButtons({
    super.key,
    required this.dividerLabel,
    this.enabled = true,
  });

  /// e.g. "OR CONTINUE WITH".
  final String dividerLabel;
  final bool enabled;

  @override
  ConsumerState<SocialSignInButtons> createState() =>
      _SocialSignInButtonsState();
}

class _SocialSignInButtonsState extends ConsumerState<SocialSignInButtons> {
  SocialProvider? _busy;

  Future<void> _signIn(SocialProvider provider) async {
    setState(() => _busy = provider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final config = await ref.read(socialConfigProvider.future);
      final credential = await ref
          .read(socialSignInServiceProvider)
          .signIn(provider, config);
      if (credential == null || !mounted) return; // cancelled

      final needsSignup = await ref
          .read(authControllerProvider.notifier)
          .signInWithSocial(credential);
      if (!mounted) return;

      if (needsSignup == null) {
        // Signed in: AuthGate shows the app underneath anything pushed.
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SocialSignupScreen(
            credential: credential,
            email: needsSignup.email,
            suggestedName: needsSignup.name ?? credential.name,
          ),
        ),
      );
    } on SocialSignInException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final available =
        ref.watch(availableSocialProvidersProvider).valueOrNull ?? const [];
    final google = available.contains(SocialProvider.google);
    final apple = available.contains(SocialProvider.apple);
    if (!google && !apple) return const SizedBox.shrink();
    final enabled = widget.enabled && _busy == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                widget.dividerLabel,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 16),
        if (apple) ...[
          // Apple's own button, as its review guidelines expect.
          IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: SignInWithAppleButton(
                key: const Key('social-apple-button'),
                text: 'Continue with Apple',
                height: 52,
                borderRadius: const BorderRadius.all(Radius.circular(26)),
                onPressed: () => _signIn(SocialProvider.apple),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (google)
          OutlinedButton.icon(
            key: const Key('social-google-button'),
            onPressed: enabled ? () => _signIn(SocialProvider.google) : null,
            icon: _busy == SocialProvider.google
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'G',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Color(0xFF4285F4),
                    ),
                  ),
            label: const Text('Continue with Google'),
          ),
      ],
    );
  }
}
