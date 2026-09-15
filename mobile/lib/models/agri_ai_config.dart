import 'package:flutter/foundation.dart';

/// Mirrors GET /api/v1/config/stripe-key on the backend — the real Stripe
/// publishable key plus the real Agri-AI Premium prices, all fetched at
/// runtime rather than compiled into the app, so an admin changing the
/// price or rotating the key via the Settings page takes effect
/// immediately, no new APK needed. See ConfigController::stripeKey().
@immutable
class AgriAiConfig {
  const AgriAiConfig({
    required this.publishableKey,
    required this.monthlyPriceUsd,
    required this.annualPriceUsd,
  });

  final String publishableKey;
  final double monthlyPriceUsd;
  final double annualPriceUsd;

  /// The annual plan's real price, expressed as an effective monthly
  /// figure for the "$X.XX/month" comparison shown next to the monthly
  /// plan — derived from the real annual price, not a second hardcoded
  /// number.
  double get annualEffectiveMonthlyUsd => annualPriceUsd / 12;

  factory AgriAiConfig.fromJson(Map<String, dynamic> json) {
    return AgriAiConfig(
      publishableKey: json['publishable_key'] as String,
      monthlyPriceUsd: (json['monthly_price_usd'] as num).toDouble(),
      annualPriceUsd: (json['annual_price_usd'] as num).toDouble(),
    );
  }
}
