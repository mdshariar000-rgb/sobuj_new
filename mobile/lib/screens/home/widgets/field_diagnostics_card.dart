import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/weather_snapshot.dart';
import '../../../providers/weather_providers.dart';
import '../../../theme/app_colors.dart';

/// A curated set of true, general horticultural tips — not derived from any
/// per-user sensor data, so it's labeled as a general tip rather than
/// personalized "your soil/your zone" advice.
const _tips = [
  'Water in the early morning to reduce evaporation and fungal growth.',
  'Rotate crops each season to keep soil nutrients balanced.',
  'Mulching helps retain soil moisture and suppress weeds.',
  'Yellowing lower leaves often signal a nitrogen deficiency.',
  'Companion planting basil near tomatoes can help deter pests.',
];

/// Mirrors the reference design's "Field Diagnostics" card shape. Atmosphere
/// and today's rainfall are real readings from Open-Meteo for the user's
/// approximate location — there's still no soil-moisture sensor anywhere in
/// this app, so that tile was swapped for a real rainfall figure rather than
/// a fabricated reading.
class FieldDiagnosticsCard extends ConsumerWidget {
  const FieldDiagnosticsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tip = _tips[DateTime.now().day % _tips.length];
    final weatherAsync = ref.watch(currentWeatherProvider);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.eco_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  'WEATHER IN YOUR AREA',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                _StatusPill(weatherAsync: weatherAsync),
              ],
            ),
            const SizedBox(height: 14),
            weatherAsync.when(
              loading: () => const Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.wb_sunny_outlined,
                      label: 'Atmosphere',
                      value: '…',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.water_drop_outlined,
                      label: 'Rainfall Today',
                      value: '…',
                    ),
                  ),
                ],
              ),
              error: (_, _) => const Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.wb_sunny_outlined,
                      label: 'Atmosphere',
                      value: 'Unavailable',
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.water_drop_outlined,
                      label: 'Rainfall Today',
                      value: 'Unavailable',
                    ),
                  ),
                ],
              ),
              data: (weather) {
                if (weather == null) {
                  return Row(
                    children: [
                      const Icon(
                        Icons.location_off_outlined,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Add your location in your profile to see live '
                          'weather here.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.wb_sunny_outlined,
                        label: 'Atmosphere',
                        value:
                            '${weather.temperatureC.round()}°C · '
                            '${weather.humidityPercent.round()}%',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.water_drop_outlined,
                        label: 'Rainfall Today',
                        value:
                            '${weather.rainfallTodayMm.toStringAsFixed(1)} mm',
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tip: $tip',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.weatherAsync});

  final AsyncValue<WeatherSnapshot?> weatherAsync;

  @override
  Widget build(BuildContext context) {
    final (label, color, textColor) = switch (weatherAsync) {
      AsyncData(value: final weather) when weather != null => (
        'Live',
        AppColors.mint,
        AppColors.forestDark,
      ),
      AsyncError() => (
        'Unavailable',
        AppColors.surfaceMuted,
        AppColors.textMuted,
      ),
      _ => ('Loading…', AppColors.surfaceMuted, AppColors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}
