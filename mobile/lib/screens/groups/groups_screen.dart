import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/group_providers.dart';
import '../../theme/app_colors.dart';
import '../profile/profile_screen.dart';
import '../shell/widgets/coming_soon_view.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import 'widgets/group_card.dart';
import 'widgets/groups_hero_header.dart';

/// The Groups tab: browse/search groups, join/leave inline, and jump into a
/// group's own page (discussion thread).
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  static const _debounceDuration = Duration(milliseconds: 400);

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  Timer? _debounce;

  int? _busyGroupId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(groupsListProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      ref.read(groupsFiltersProvider.notifier).setSearch(value);
    });
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$feature is coming soon.')));
  }

  Future<void> _toggleMembership(int groupId, bool isMember) async {
    setState(() => _busyGroupId = groupId);
    try {
      if (isMember) {
        await ref.read(groupsListProvider.notifier).leaveGroup(groupId);
      } else {
        await ref.read(groupsListProvider.notifier).joinGroup(groupId);
      }
    } finally {
      if (mounted) setState(() => _busyGroupId = null);
    }
  }

  void _showAllCategories(String? selected, List<String> categories) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filter by category',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final category in categories)
                    ChoiceChip(
                      label: Text(category),
                      selected: selected == category,
                      onSelected: (_) {
                        ref
                            .read(groupsFiltersProvider.notifier)
                            .setCategory(category);
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsListProvider);
    final selectedCategory = ref.watch(groupsFiltersProvider).category;
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final userName = currentUser?.name ?? '?';
    // The real, admin-managed list (already sorted by name on the backend)
    // — not an approximation built from whatever groups happen to have
    // loaded so far, so every real category shows up immediately even
    // before any group using it has been fetched.
    final categoryNames =
        ref.watch(groupCategoriesProvider).valueOrNull?.map((c) => c.name).toList() ??
        const <String>[];

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton(
        heroTag: 'groups-fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
        ),
        tooltip: 'New group',
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(groupsListProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: GroupsHeroHeader(
                userName: userName,
                avatarUrl: currentUser?.avatarUrl,
                onAvatarTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                onNotificationsTap: () => _comingSoon('Notifications'),
              ),
            ),
            // Pinned so the search bar is the only thing that stays fixed
            // once scrolled — the header, categories, banner and section
            // title all scroll away above it.
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickySearchBarDelegate(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: 'Search groups, crops, techniques...',
                            prefixIcon: Icon(Icons.search),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.mint,
                          foregroundColor: AppColors.forestDark,
                        ),
                        onPressed: () =>
                            _showAllCategories(selectedCategory, categoryNames),
                        icon: const Icon(Icons.tune),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'CATEGORIES',
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: AppColors.textMuted,
                          ),
                    ),
                    const Spacer(),
                    if (categoryNames.length > 3)
                      Text(
                        'Swipe →',
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _CategoryChip(
                      label: 'All',
                      selected: selectedCategory == null,
                      onTap: () => ref
                          .read(groupsFiltersProvider.notifier)
                          .setCategory(null),
                    ),
                    for (final category in categoryNames) ...[
                      const SizedBox(width: 8),
                      _CategoryChip(
                        label: category,
                        selected: selectedCategory == category,
                        onTap: () => ref
                            .read(groupsFiltersProvider.notifier)
                            .setCategory(category),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _CreateGroupBanner(
                  onCreate: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explore & Join Groups',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Recommended agronomy circles',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (groupsAsync.valueOrNull != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${groupsAsync.valueOrNull!.total} Active',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            groupsAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(child: Text('$error')),
              ),
              data: (state) {
                if (state.groups.isEmpty) {
                  return const SliverFillRemaining(
                    child: ComingSoonView(
                      icon: Icons.groups_outlined,
                      title: 'No groups found',
                      message: 'Try a different search, or start your own.',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.only(bottom: 88),
                  sliver: SliverList.builder(
                    itemCount: state.groups.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= state.groups.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final group = state.groups[index];
                      return GroupCard(
                        group: group,
                        isBusy: _busyGroupId == group.id,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GroupDetailScreen(group: group),
                          ),
                        ),
                        onJoin: () => _toggleMembership(
                          group.id,
                          group.isMember ?? false,
                        ),
                        onLeave: () => _toggleMembership(
                          group.id,
                          group.isMember ?? false,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Pins the search bar (and only the search bar) to the top once the header
/// above it has scrolled out of view.
class _StickySearchBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickySearchBarDelegate({required this.child});

  final Widget child;

  static const _height = 76.0;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickySearchBarDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.forestPanel,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.label,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: Colors.white,
      shape: const StadiumBorder(),
      side: selected
          ? BorderSide.none
          : const BorderSide(color: AppColors.border),
    );
  }
}

class _CreateGroupBanner extends StatelessWidget {
  const _CreateGroupBanner({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mint.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a Group',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Start your local farming circle or niche crop club.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onCreate,
            style: FilledButton.styleFrom(minimumSize: Size.zero),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
