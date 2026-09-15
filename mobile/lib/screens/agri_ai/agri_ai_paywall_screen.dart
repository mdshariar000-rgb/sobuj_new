import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/agri_ai_config.dart';
import '../../providers/subscription_providers.dart';
import '../../theme/app_colors.dart';
import 'agri_ai_checkout_screen.dart';

/// Which plan is selected — the real prices live in [AgriAiConfig], fetched
/// from the backend (see agriAiConfigProvider) rather than hardcoded here,
/// so an admin changing the price takes effect immediately in the app too.
enum AgriAiPlan {
  monthly('monthly'),
  annual('annual');

  const AgriAiPlan(this.value);

  final String value;
}

/// Shown instead of the chat UI when the signed-in user has no active
/// Agri-AI subscription (see AgriAiScreen) — matches the shared
/// "Shobuj Agri-AI Premium" design, but every feature bullet below describes
/// what the assistant actually does (unlimited chat + real photo diagnosis
/// via Gemini) rather than the reference design's fabricated modules
/// ("Hyper-Local Microclimate Spore Alerts", precision percentages, a
/// "ShobujPay" wallet) — none of that exists in this app.
class AgriAiPaywallScreen extends ConsumerStatefulWidget {
  const AgriAiPaywallScreen({super.key});

  @override
  ConsumerState<AgriAiPaywallScreen> createState() =>
      _AgriAiPaywallScreenState();
}

class _AgriAiPaywallScreenState extends ConsumerState<AgriAiPaywallScreen> {
  AgriAiPlan _selectedPlan = AgriAiPlan.annual;

  void _startTrial() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AgriAiCheckoutScreen(plan: _selectedPlan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(agriAiConfigProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Shobuj Agri-AI Premium'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: _ProTierBadge()),
          ),
        ],
      ),
      body: SafeArea(
        child: configAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('$error', textAlign: TextAlign.center),
            ),
          ),
          data: (config) => _PaywallBody(
            config: config,
            selectedPlan: _selectedPlan,
            onSelectPlan: (plan) => setState(() => _selectedPlan = plan),
            onStartTrial: _startTrial,
          ),
        ),
      ),
    );
  }
}

class _PaywallBody extends StatelessWidget {
  const _PaywallBody({
    required this.config,
    required this.selectedPlan,
    required this.onSelectPlan,
    required this.onStartTrial,
  });

  final AgriAiConfig config;
  final AgriAiPlan selectedPlan;
  final ValueChanged<AgriAiPlan> onSelectPlan;
  final VoidCallback onStartTrial;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const _HeroCard(),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Text(
                    'Everything in Pro',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const Spacer(),
                  Text(
                    '${_features.length} Modules',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final feature in _features) ...[
                _FeatureRow(feature: feature),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              const Text(
                'Select Your Membership',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 12),
              _PlanCard(
                plan: AgriAiPlan.annual,
                config: config,
                selected: selectedPlan == AgriAiPlan.annual,
                onTap: () => onSelectPlan(AgriAiPlan.annual),
              ),
              const SizedBox(height: 10),
              _PlanCard(
                plan: AgriAiPlan.monthly,
                config: config,
                selected: selectedPlan == AgriAiPlan.monthly,
                onTap: () => onSelectPlan(AgriAiPlan.monthly),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Cancel anytime from Manage Subscription',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: onStartTrial,
                icon: const Icon(Icons.bolt, size: 18),
                label: const Text('Start 7-Day Free Trial'),
              ),
              const SizedBox(height: 6),
              Text(
                selectedPlan == AgriAiPlan.annual
                    ? 'Then \$${config.annualPriceUsd.toStringAsFixed(2)}/year. Cancel anytime.'
                    : 'Then \$${config.monthlyPriceUsd.toStringAsFixed(2)}/month. Cancel anytime.',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Feature {
  const _Feature(this.icon, this.title, this.description);

  final IconData icon;
  final String title;
  final String description;
}

const _features = [
  _Feature(
    Icons.biotech_outlined,
    'Unlimited Plant & Tree Diagnosis',
    'Send as many leaf or plant photos as you need for AI-powered health diagnosis — no daily limit.',
  ),
  _Feature(
    Icons.eco_outlined,
    'Personalized Farming Guidance',
    'Ask unlimited questions about planting, pruning, soil, watering, and pest management.',
  ),
  _Feature(
    Icons.bolt_outlined,
    'Instant, 24/7 Responses',
    'No queue and no waiting — FloraAI answers the moment you send a message, any time of day.',
  ),
];

class _ProTierBadge extends StatelessWidget {
  const _ProTierBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Pro Tier',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.forestDark,
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.mint),
            ),
            child: const Text(
              'FLORAAI PREMIUM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.mint,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.spa, color: AppColors.forestDark),
          ),
          const SizedBox(height: 16),
          const Text(
            'Unlock Unlimited\nAgronomic Intelligence',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 22,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Real-time plant diagnosis and unlimited farming guidance from '
            'FloraAI, powered by Gemini.',
            style: TextStyle(color: AppColors.textOnDarkMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.feature});

  final _Feature feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.buttonMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(feature.icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  feature.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.config,
    required this.selected,
    required this.onTap,
  });

  final AgriAiPlan plan;
  final AgriAiConfig config;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isAnnual = plan == AgriAiPlan.annual;
    final effectiveMonthly = isAnnual
        ? config.annualEffectiveMonthlyUsd
        : config.monthlyPriceUsd;
    // A real percentage derived from the two real prices — only shown when
    // annual genuinely costs less per month than monthly, never a
    // hardcoded claim that could go stale if an admin changes either price.
    final savingsPercent = isAnnual && config.monthlyPriceUsd > 0
        ? (1 - (config.annualEffectiveMonthlyUsd / config.monthlyPriceUsd)) * 100
        : 0.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.buttonMuted : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isAnnual ? 'Annual Membership' : 'Monthly Plan',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      if (isAnnual && savingsPercent > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mint,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Save ${savingsPercent.round()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.forestDark,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isAnnual
                        ? 'Billed \$${config.annualPriceUsd.toStringAsFixed(2)}/yr • includes 7-day free trial'
                        : 'Cancel anytime, billed monthly',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${effectiveMonthly.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.primary,
                  ),
                ),
                const Text(
                  '/month',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
