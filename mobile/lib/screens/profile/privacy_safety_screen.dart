import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../services/social_sign_in_service.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_screen.dart';
import 'address_screen.dart';
import 'blocked_users_screen.dart';

/// Profile → Privacy & Safety: blocked users, the legal pages, and permanent
/// account deletion (App Store Guideline 5.1.1(v) requires deletion to be
/// available inside the app, not only via email or a website).
class PrivacySafetyScreen extends ConsumerWidget {
  const PrivacySafetyScreen({super.key});

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DeleteAccountDialog(),
    );

    if (deleted == true && context.mounted) {
      // The auth state is now signed-out; unwind to the root so the auth
      // gate's login screen is what's left.
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Privacy & Safety'),
        backgroundColor: AppColors.forestDark,
        foregroundColor: Colors.white,
        // The theme's title style carries its own dark color, which beats
        // foregroundColor — set white explicitly for this dark bar.
        titleTextStyle: Theme.of(
          context,
        ).appBarTheme.titleTextStyle?.copyWith(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            key: const Key('address-row'),
            leading: const Icon(Icons.home_outlined),
            title: const Text('Your address'),
            subtitle: const Text('Private — only you and our team see it'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddressScreen())),
          ),
          ListTile(
            key: const Key('blocked-users-row'),
            leading: const Icon(Icons.block),
            title: const Text('Blocked users'),
            subtitle: const Text('People whose content you no longer see'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Use'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const TermsScreen())),
          ),
          const Divider(height: 32),
          ListTile(
            key: const Key('delete-account-row'),
            leading: const Icon(Icons.delete_forever, color: AppColors.error),
            title: const Text(
              'Delete account',
              style: TextStyle(color: AppColors.error),
            ),
            subtitle: const Text(
              'Permanently remove your account and all your data',
            ),
            onTap: () => _confirmDeleteAccount(context),
          ),
        ],
      ),
    );
  }
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  bool _deleting = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  /// A Google/Apple account with no password confirms by signing in with
  /// that provider again.
  SocialProvider? get _confirmWith {
    final user = ref.watch(authControllerProvider).valueOrNull;
    if (user == null || user.hasPassword) return null;
    return user.signedInWith
        .map(SocialProvider.fromValue)
        .whereType<SocialProvider>()
        .firstOrNull;
  }

  Future<void> _delete() async {
    final provider = _confirmWith;
    if (provider != null) return _deleteWithProvider(provider);

    if (_passwordController.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .deleteAccount(password: _passwordController.text);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = e.message;
      });
    }
  }

  Future<void> _deleteWithProvider(SocialProvider provider) async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final config = await ref.read(socialConfigProvider.future);
      final credential = await ref
          .read(socialSignInServiceProvider)
          .signIn(provider, config);
      if (credential == null) {
        if (mounted) setState(() => _deleting = false);
        return;
      }
      await ref
          .read(authControllerProvider.notifier)
          .deleteAccount(confirmWith: credential);
      if (mounted) Navigator.of(context).pop(true);
    } on SocialSignInException catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = e.message;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final confirmWith = _confirmWith;

    return AlertDialog(
      title: const Text('Delete your account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your profile, listings, posts, '
              'comments, events, messages, and photos. This cannot be undone.',
            ),
            const SizedBox(height: 16),
            if (confirmWith != null) ...[
              Text(
                'To confirm, sign in with ${confirmWith.label} again.',
                key: const Key('delete-account-confirm-with'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
            ] else
              TextField(
                key: const Key('delete-account-password'),
                controller: _passwordController,
                obscureText: true,
                enabled: !_deleting,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Confirm your password',
                  errorText: _error,
                  errorMaxLines: 3,
                ),
                onSubmitted: (_) => _delete(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('delete-account-confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _deleting ? null : _delete,
          child: _deleting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  confirmWith != null
                      ? 'Confirm with ${confirmWith.label}'
                      : 'Delete account',
                ),
        ),
      ],
    );
  }
}
