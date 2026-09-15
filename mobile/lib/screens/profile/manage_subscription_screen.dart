import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/subscription_status.dart';
import '../../providers/subscription_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../agri_ai/agri_ai_paywall_screen.dart';

/// Profile > Manage Subscription — real status pulled from
/// GET /subscriptions/me (Cashier's own subscription state, kept in sync by
/// Stripe webhooks), with a real Cancel action wired to
/// DELETE /subscriptions/me. Shown for both subscribed and never-subscribed
/// users; an unsubscribed user sees a prompt into the paywall instead of a
/// cancel button.
class ManageSubscriptionScreen extends ConsumerWidget {
  const ManageSubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(subscriptionStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Manage Subscription')),
      body: SafeArea(
        child: statusAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _ErrorState(
            message: error is ApiException
                ? error.message
                : 'Could not load your subscription status.',
            onRetry: () => ref.invalidate(subscriptionStatusProvider),
          ),
          data: (status) => _ManageSubscriptionBody(status: status),
        ),
      ),
    );
  }
}

class _ManageSubscriptionBody extends ConsumerWidget {
  const _ManageSubscriptionBody({required this.status});

  final SubscriptionStatus status;

  Future<void> _confirmCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Agri-AI Premium?'),
        content: const Text(
          "You'll keep access until the end of your current billing "
          "period, then FloraAI chat and diagnosis will be locked again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep Subscription'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Cancel Subscription',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(subscriptionActionsProvider).cancel();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Your subscription has been canceled.'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!status.hasAccess && status.status == null) {
      return _NotSubscribedState(
        onSubscribe: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AgriAiPaywallScreen()),
        ),
      );
    }

    final dateFormat = DateFormat('MMMM d, y');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.forestDark, AppColors.forestPanel],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.mint.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.mint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.spa, color: AppColors.forestDark),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Shobuj Agri-AI Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  _StatusBadge(status: status),
                ],
              ),
              const SizedBox(height: 16),
              _InfoRow(
                label: 'Plan',
                value: switch (status.plan) {
                  'monthly' => 'Monthly',
                  'annual' => 'Annual',
                  _ => '—',
                },
              ),
              if (status.onTrial && status.trialEndsAt != null)
                _InfoRow(
                  label: 'Free trial ends',
                  value: dateFormat.format(status.trialEndsAt!),
                ),
              if (status.cancelAtPeriodEnd && status.endsAt != null)
                _InfoRow(
                  label: 'Access ends',
                  value: dateFormat.format(status.endsAt!),
                )
              else if (status.renewsAt != null)
                _InfoRow(
                  label: 'Renews on',
                  value: dateFormat.format(status.renewsAt!),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        if (status.cancelAtPeriodEnd)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 18, color: AppColors.textMuted),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your subscription is set to cancel. You can keep using '
                    'FloraAI until the date above.',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () => _confirmCancel(context, ref),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Cancel Subscription'),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final label = status.cancelAtPeriodEnd
        ? 'Canceling'
        : status.onTrial
        ? 'Trial'
        : status.hasAccess
        ? 'Active'
        : 'Inactive';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.mint),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.mint,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textOnDarkMuted,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotSubscribedState extends StatelessWidget {
  const _NotSubscribedState({required this.onSubscribe});

  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.spa_outlined, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              "You're not subscribed to Agri-AI Premium",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Subscribe to unlock unlimited plant & tree diagnosis and '
              'farming guidance from FloraAI.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onSubscribe,
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('View Plans'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
