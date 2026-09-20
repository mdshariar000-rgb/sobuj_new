import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/ai_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../theme/app_colors.dart';
import '../../legal/privacy_policy_screen.dart';

/// Shown once per account before the first Agri-AI chat: names Google's Gemini
/// as the service that receives the user's messages and photos, and asks for
/// explicit permission. Declining leaves the user here — the assistant simply
/// stays unavailable until they agree.
class AiConsentView extends ConsumerWidget {
  const AiConsentView({super.key});

  Future<void> _agree(WidgetRef ref) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user == null) return;

    await ref.read(secureStorageProvider).saveAiConsent(user.id);
    ref.invalidate(aiConsentProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Agri-AI Assistant')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              const Icon(Icons.shield_outlined, size: 40, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Before you chat with FloraAI',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'FloraAI is powered by Google\'s Gemini AI. To answer you, the '
                'messages and plant photos you send here are shared with '
                'Google. Nothing else from your account is sent.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Its answers are general guidance and can be wrong — they are '
                'not professional agronomic advice.',
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                ),
                child: const Text('Read the Privacy Policy'),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('ai-consent-agree'),
                  onPressed: () => _agree(ref),
                  child: const Text('I agree — continue'),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'You can stop using the assistant at any time.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
