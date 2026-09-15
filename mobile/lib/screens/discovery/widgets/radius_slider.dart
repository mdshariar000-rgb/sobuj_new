import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../providers/discovery_providers.dart';

/// Local (uncommitted) slider value while dragging, so the label updates
/// smoothly without re-triggering an API call on every pixel of drag — the
/// actual filter (and its refetch) only commits on release.
class RadiusSlider extends ConsumerStatefulWidget {
  const RadiusSlider({super.key});

  @override
  ConsumerState<RadiusSlider> createState() => _RadiusSliderState();
}

class _RadiusSliderState extends ConsumerState<RadiusSlider> {
  double? _draftValue;

  @override
  Widget build(BuildContext context) {
    final committedRadius = ref.watch(
      discoveryFiltersProvider.select((f) => f.radiusKm),
    );
    final displayValue = _draftValue ?? committedRadius;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.social_distance, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Slider(
              value: displayValue,
              min: AppConfig.minRadiusKm,
              max: AppConfig.maxRadiusKm,
              divisions: (AppConfig.maxRadiusKm - AppConfig.minRadiusKm)
                  .round(),
              label: '${displayValue.round()} km',
              onChanged: (value) => setState(() => _draftValue = value),
              onChangeEnd: (value) {
                setState(() => _draftValue = null);
                ref.read(discoveryFiltersProvider.notifier).setRadiusKm(value);
              },
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${displayValue.round()} km',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
