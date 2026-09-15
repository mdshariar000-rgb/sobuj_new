import 'package:flutter/foundation.dart';

/// Mirrors SubscriptionResource on the backend — the signed-in user's
/// Agri-AI Premium subscription (or its absence). Backed entirely by
/// Laravel Cashier's own `subscriptions` table (kept in sync by real Stripe
/// webhooks), not a status this app invents or caches independently.
@immutable
class SubscriptionStatus {
  const SubscriptionStatus({
    required this.hasAccess,
    this.plan,
    this.status,
    required this.onTrial,
    this.trialEndsAt,
    required this.cancelAtPeriodEnd,
    this.renewsAt,
    this.endsAt,
  });

  final bool hasAccess;

  /// 'monthly' | 'annual' | null (no subscription, or a price Cashier holds
  /// that doesn't match either configured plan).
  final String? plan;

  /// Stripe's own subscription status string (trialing/active/past_due/
  /// canceled/...), or null if the user has never subscribed.
  final String? status;

  final bool onTrial;
  final DateTime? trialEndsAt;

  /// True once the user has canceled but their access hasn't expired yet.
  final bool cancelAtPeriodEnd;

  /// The next renewal date, while the subscription is still recurring.
  final DateTime? renewsAt;

  /// When access will actually end, once cancellation is scheduled.
  final DateTime? endsAt;

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      hasAccess: json['has_access'] as bool,
      plan: json['plan'] as String?,
      status: json['status'] as String?,
      onTrial: json['on_trial'] as bool,
      trialEndsAt: json['trial_ends_at'] != null
          ? DateTime.parse(json['trial_ends_at'] as String)
          : null,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool,
      renewsAt: json['renews_at'] != null
          ? DateTime.parse(json['renews_at'] as String)
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'] as String)
          : null,
    );
  }
}

/// The result of POST /subscriptions — either the subscription is active
/// right away, or the card needs an extra 3-D Secure confirmation step
/// before it can be finalized (common for real cards, especially EU/UK
/// ones) — see SubscriptionController::store() on the backend.
@immutable
class SubscribeResult {
  const SubscribeResult.success(this.status)
    : requiresActionClientSecret = null;

  const SubscribeResult.requiresAction(this.requiresActionClientSecret)
    : status = null;

  final SubscriptionStatus? status;
  final String? requiresActionClientSecret;

  bool get requiresAction => requiresActionClientSecret != null;
}
