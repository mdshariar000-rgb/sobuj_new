import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agri_ai_config.dart';
import '../models/subscription_status.dart';
import 'core_providers.dart';

/// The signed-in user's Agri-AI Premium status — drives the paywall gate on
/// [AgriAiScreen] and the Manage Subscription view. `autoDispose` so it
/// re-fetches fresh each time the Agri-AI tab (or Manage Subscription) is
/// revisited, the same pattern used for `mySwapOffersProvider`.
final subscriptionStatusProvider =
    FutureProvider.autoDispose<SubscriptionStatus>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      return apiClient.subscriptionStatus();
    });

/// The real Stripe publishable key and the real Agri-AI Premium prices,
/// fetched from the backend rather than compiled into the app — see
/// ApiClient.agriAiConfig().
final agriAiConfigProvider = FutureProvider.autoDispose<AgriAiConfig>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  return apiClient.agriAiConfig();
});

/// Subscribe/cancel actions for the checkout and Manage Subscription
/// screens — both mutate real Stripe state via the backend, then refresh
/// [subscriptionStatusProvider] so every screen watching it updates.
class SubscriptionActions {
  SubscriptionActions(this._ref);

  final Ref _ref;

  Future<SubscribeResult> subscribe({
    required String plan,
    required String paymentMethodId,
  }) async {
    final apiClient = _ref.read(apiClientProvider);
    final result = await apiClient.createSubscription(
      plan: plan,
      paymentMethodId: paymentMethodId,
    );
    _ref.invalidate(subscriptionStatusProvider);
    return result;
  }

  Future<SubscriptionStatus> cancel() async {
    final apiClient = _ref.read(apiClientProvider);
    final status = await apiClient.cancelSubscription();
    _ref.invalidate(subscriptionStatusProvider);
    return status;
  }
}

final subscriptionActionsProvider = Provider<SubscriptionActions>(
  (ref) => SubscriptionActions(ref),
);
