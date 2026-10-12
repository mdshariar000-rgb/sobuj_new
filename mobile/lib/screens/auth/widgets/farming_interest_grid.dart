import 'package:flutter/material.dart';

import '../../../models/enums.dart';
import '../../../theme/app_colors.dart';

/// A tappable card-grid selector for GrowingSetup — the backend's real,
/// single-select field (mirrors App\Enums\GrowingSetup). Visually similar to
/// a multi-select interest picker, but only one can be active at a time since
/// that's what the account actually stores; tapping the active card again
/// clears it (the field is optional).
class FarmingInterestGrid extends StatelessWidget {
  const FarmingInterestGrid({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final GrowingSetup? value;
  final ValueChanged<GrowingSetup?> onChanged;

  static const _icons = {
    GrowingSetup.balcony: (Icons.balcony_outlined, 'Containers & pots'),
    GrowingSetup.indoor: (Icons.wb_sunny_outlined, 'Grow lights & shelves'),
    GrowingSetup.backyard: (Icons.yard_outlined, 'In-ground beds'),
    GrowingSetup.rooftop: (Icons.roofing_outlined, 'Rooftop containers'),
    GrowingSetup.communityGarden: (Icons.groups_outlined, 'Shared plots'),
    GrowingSetup.greenhouse: (Icons.spa_outlined, 'Controlled climate'),
    GrowingSetup.allotment: (Icons.grass_outlined, 'Rented plot'),
  };

  @override
  Widget build(BuildContext context) {
    return GridView(
      // Explicit zero — otherwise a shrink-wrapped grid pads itself by the
      // status-bar inset, leaving a blank gap above the cards.
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Card height grows with the text size, so titles aren't clipped with
      // Larger Text on (a fixed aspect ratio would cut them off).
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 24 + MediaQuery.textScalerOf(context).scale(46),
      ),
      children: GrowingSetup.values.map((setup) {
        final isSelected = value == setup;
        final (icon, subtitle) = _icons[setup]!;

        return _InterestCard(
          icon: icon,
          title: setup.label,
          subtitle: subtitle,
          isSelected: isSelected,
          onTap: () => onChanged(isSelected ? null : setup),
        );
      }).toList(),
    );
  }
}

class _InterestCard extends StatelessWidget {
  const _InterestCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceMuted,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
