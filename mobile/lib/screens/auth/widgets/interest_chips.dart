import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// The sign-up interests — must match App\Support\Interests on the backend,
/// which puts the user in each picked interest's group.
const signUpInterests = [
  'Learning to garden',
  'Buyer',
  'Seller',
  'Garden Project',
  'Community Engagement',
  'Sustainability',
  'Community Gardening',
  'Wildlife & Biodiversity',
  'Research & Education',
];

/// Multi-select chips for "What are your interests?".
class InterestChips extends StatelessWidget {
  const InterestChips({
    super.key,
    required this.selected,
    required this.onToggle,
  });

  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final interest in signUpInterests)
          FilterChip(
            key: Key('interest-$interest'),
            label: Text(interest),
            selected: selected.contains(interest),
            onSelected: (_) => onToggle(interest),
            selectedColor: AppColors.primary,
            checkmarkColor: Colors.white,
            labelStyle: TextStyle(
              color: selected.contains(interest)
                  ? Colors.white
                  : AppColors.textDark,
              fontWeight: FontWeight.w600,
            ),
            backgroundColor: AppColors.surfaceMuted,
            shape: const StadiumBorder(),
            side: BorderSide.none,
          ),
      ],
    );
  }
}
