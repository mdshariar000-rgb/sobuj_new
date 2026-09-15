import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/discovery_providers.dart';

class ViewModeToggle extends ConsumerWidget {
  const ViewModeToggle({super.key, this.compact = false});

  /// A plain icon toggle (no label/segmented chrome) for tight spaces, e.g.
  /// alongside the location/sort dropdowns.
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(viewModeProvider);

    if (compact) {
      final isMap = mode == DiscoveryViewMode.map;
      return IconButton.filledTonal(
        tooltip: isMap ? 'Switch to list view' : 'Switch to map view',
        onPressed: () => ref.read(viewModeProvider.notifier).state = isMap
            ? DiscoveryViewMode.list
            : DiscoveryViewMode.map,
        icon: Icon(isMap ? Icons.view_list : Icons.map_outlined),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<DiscoveryViewMode>(
          segments: const [
            ButtonSegment(
              value: DiscoveryViewMode.list,
              label: Text('List'),
              icon: Icon(Icons.view_list),
            ),
            ButtonSegment(
              value: DiscoveryViewMode.map,
              label: Text('Map'),
              icon: Icon(Icons.map_outlined),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (selection) {
            ref.read(viewModeProvider.notifier).state = selection.first;
          },
        ),
      ),
    );
  }
}
