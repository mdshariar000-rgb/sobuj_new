import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/group_providers.dart';
import '../../../theme/app_colors.dart';

/// A dropdown over the real, admin-managed category list (see
/// GroupCategoryResource/GroupCategoryController on the backend) — group
/// categories are curated from the admin panel, not typed freely here.
class GroupCategoryPicker extends ConsumerWidget {
  const GroupCategoryPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  /// The selected category's name, or null for "no category".
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(groupCategoriesProvider);

    return categoriesAsync.when(
      loading: () => const _PickerField(
        enabled: false,
        hint: 'Loading categories…',
      ),
      error: (error, _) => _PickerField(
        enabled: false,
        hint: 'Could not load categories',
      ),
      data: (categories) => DropdownButtonFormField<String?>(
        key: const Key('create-group-category-field'),
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(hintText: 'Select a category'),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('No category'),
          ),
          for (final category in categories)
            DropdownMenuItem<String?>(
              value: category.name,
              child: Text(category.name),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.enabled, required this.hint});

  final bool enabled;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(enabled: false),
      child: Text(hint, style: const TextStyle(color: AppColors.textMuted)),
    );
  }
}
