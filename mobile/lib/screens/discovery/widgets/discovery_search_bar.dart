import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/discovery_providers.dart';
import '../../../theme/app_colors.dart';

class DiscoverySearchBar extends ConsumerStatefulWidget {
  const DiscoverySearchBar({super.key});

  @override
  ConsumerState<DiscoverySearchBar> createState() => _DiscoverySearchBarState();
}

class _DiscoverySearchBarState extends ConsumerState<DiscoverySearchBar> {
  static const _debounceDuration = Duration(milliseconds: 400);

  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(discoveryFiltersProvider).searchTerm,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      ref.read(discoveryFiltersProvider.notifier).setSearchTerm(value);
    });
  }

  void _onClear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(discoveryFiltersProvider.notifier).setSearchTerm('');
  }

  @override
  Widget build(BuildContext context) {
    // A search can also start from Home's search bar — show its term here.
    ref.listen(discoveryFiltersProvider.select((f) => f.searchTerm), (_, term) {
      if (term != _controller.text) _controller.text = term;
    });
    final hasText = ref.watch(
      discoveryFiltersProvider.select(
        (filters) => filters.searchTerm.isNotEmpty,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search seeds, plants, cuttings, tools…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _onClear,
                  tooltip: 'Clear search',
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceContainer,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 0,
            horizontal: 16,
          ),
        ),
      ),
    );
  }
}
