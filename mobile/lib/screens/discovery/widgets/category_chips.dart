import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/enums.dart';
import '../../../providers/discovery_providers.dart';
import '../../../theme/app_colors.dart';

IconData categoryIcon(ListingType type) {
  switch (type) {
    case ListingType.seedsScions:
      return Icons.grain;
    case ListingType.livePlants:
      return Icons.local_florist_outlined;
    case ListingType.organicFertilizers:
      return Icons.science_outlined;
    case ListingType.farmTools:
      return Icons.handyman_outlined;
    case ListingType.harvestProduce:
      return Icons.agriculture_outlined;
    case ListingType.compostSoils:
      return Icons.compost_outlined;
  }
}

class CategoryChips extends ConsumerWidget {
  const CategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      discoveryFiltersProvider.select((filters) => filters.category),
    );

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: ListingType.values.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Center(
              child: Text(
                'CATEGORY:',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            );
          }

          final type = ListingType.values[index - 1];
          final isSelected = selected == type;

          return ChoiceChip(
            avatar: Icon(categoryIcon(type), size: 16),
            label: Text(type.label),
            selected: isSelected,
            onSelected: (_) => ref
                .read(discoveryFiltersProvider.notifier)
                .toggleCategory(type),
          );
        },
      ),
    );
  }
}
