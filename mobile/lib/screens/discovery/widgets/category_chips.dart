import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/discovery_providers.dart';
import '../../../theme/app_colors.dart';

/// A small decorative icon keyed to a handful of category strings the admin
/// panel's Listing Categories list is seeded with — purely cosmetic pairing
/// for a real, existing category value (never invents one that isn't there).
/// Anything that doesn't match falls back to a generic marketplace icon.
IconData categoryIcon(String? category) {
  final normalized = category?.toLowerCase() ?? '';
  if (normalized.contains('seed')) return Icons.spa;
  if (normalized.contains('plant')) return Icons.yard;
  if (normalized.contains('fertili')) return Icons.science;
  if (normalized.contains('tool') || normalized.contains('equipment')) {
    return Icons.construction;
  }
  if (normalized.contains('harvest') || normalized.contains('produce')) {
    return Icons.shopping_basket;
  }
  if (normalized.contains('compost') || normalized.contains('soil')) {
    return Icons.eco;
  }
  return Icons.eco_outlined;
}

class CategoryChips extends ConsumerWidget {
  const CategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      discoveryFiltersProvider.select((filters) => filters.category),
    );
    final categoriesAsync = ref.watch(listingCategoriesProvider);
    final categories = categoriesAsync.valueOrNull ?? const [];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
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

          final category = categories[index - 1];
          final isSelected = selected == category.name;

          return ChoiceChip(
            avatar: Icon(categoryIcon(category.name), size: 16),
            label: Text(category.name),
            selected: isSelected,
            onSelected: (_) => ref
                .read(discoveryFiltersProvider.notifier)
                .toggleCategory(category.name),
          );
        },
      ),
    );
  }
}
