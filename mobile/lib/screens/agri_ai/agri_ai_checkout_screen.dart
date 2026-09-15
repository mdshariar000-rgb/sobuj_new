import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import '../../models/agri_ai_config.dart';
import '../../providers/subscription_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import 'agri_ai_paywall_screen.dart';

/// The real in-app checkout for Agri-AI Premium — matches the shared
/// "Checkout & Subscription" design, but drops what isn't real: no Apple Pay
/// (this app has no iOS build) and no "ShobujPay Direct Agri-Wallet" balance
/// (no wallet/credit system exists anywhere in this app). Card details are
/// tokenized on-device by the Stripe SDK and never pass through this app's
/// own server — see SubscriptionController::store() on the backend.
class AgriAiCheckoutScreen extends ConsumerStatefulWidget {
  const AgriAiCheckoutScreen({super.key, required this.plan});

  final AgriAiPlan plan;

  @override
  ConsumerState<AgriAiCheckoutScreen> createState() =>
      _AgriAiCheckoutScreenState();
}

class _AgriAiCheckoutScreenState extends ConsumerState<AgriAiCheckoutScreen> {
  final _cardController = CardFormEditController();
  bool _stripeReady = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  AgriAiConfig? _config;

  @override
  void initState() {
    super.initState();
    _initStripe();
  }

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _initStripe() async {
    try {
      final config = await ref.read(agriAiConfigProvider.future);
      Stripe.publishableKey = config.publishableKey;
      await Stripe.instance.applySettings();
      if (mounted) {
        setState(() {
          _config = config;
          _stripeReady = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorMessage =
              'Could not load the payment form. Please try again.',
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_cardController.details.complete) {
      setState(() => _errorMessage = 'Enter your complete card details.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final paymentMethod = await Stripe.instance.createPaymentMethod(
        params: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      final actions = ref.read(subscriptionActionsProvider);
      var result = await actions.subscribe(
        plan: widget.plan.value,
        paymentMethodId: paymentMethod.id,
      );

      if (result.requiresAction) {
        // 3-D Secure confirmation — realistic for real cards, especially
        // EU/UK-issued ones. Once confirmed, the subscription is already
        // active on Stripe's side (Cashier creates it before the payment
        // confirms), so there's no need to call the endpoint again.
        await Stripe.instance.handleNextAction(
          result.requiresActionClientSecret!,
        );
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(
        () => _errorMessage =
            'Your card could not be processed. Please check your details and try again.',
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Checkout & Subscription'),
        ),
        body: Center(
          child: _errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final isAnnual = widget.plan == AgriAiPlan.annual;
    final dueTotal = isAnnual ? config.annualPriceUsd : config.monthlyPriceUsd;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Checkout & Subscription'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Icon(
                Icons.lock_outline,
                size: 18,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      const Icon(Icons.eco, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        isAnnual
                            ? 'Shobuj Agri-AI Pro (Annual Pass)'
                            : 'Shobuj Agri-AI Pro (Monthly)',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isAnnual
                        ? '7 Days Free Trial. Then \$${dueTotal.toStringAsFixed(2)}/year.'
                        : '7 Days Free Trial. Then \$${dueTotal.toStringAsFixed(2)}/month.',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _PriceRow(
                          label: 'Subtotal',
                          value: '\$${dueTotal.toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 8),
                        _PriceRow(
                          label: '7-Day Trial Discount',
                          value: '-\$${dueTotal.toStringAsFixed(2)}',
                          valueColor: AppColors.primary,
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Divider(height: 1, color: AppColors.border),
                        ),
                        const _PriceRow(
                          label: 'Due Today',
                          value: '\$0.00',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Payment Method',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: CardFormField(
                      controller: _cardController,
                      style: CardFormStyle(
                        backgroundColor: AppColors.surfaceContainer,
                        textColor: AppColors.textDark,
                        placeholderColor: AppColors.textMuted,
                      ),
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your card details are tokenized directly by Stripe and '
                            'never stored on our servers.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.undo, size: 18, color: AppColors.textMuted),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Cancel anytime from Manage Subscription — you keep '
                            'access until the end of your current period.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainer,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: FilledButton.icon(
                onPressed: (_stripeReady && !_isSubmitting) ? _submit : null,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.bolt, size: 18),
                label: const Text('Start Free Trial & Subscribe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final weight = bold ? FontWeight.w800 : FontWeight.w500;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: weight,
            fontSize: bold ? 15 : 13,
            color: bold ? AppColors.textDark : AppColors.textMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: weight,
            fontSize: bold ? 15 : 13,
            color:
                valueColor ?? (bold ? AppColors.textDark : AppColors.textDark),
          ),
        ),
      ],
    );
  }
}
