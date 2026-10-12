import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/group.dart';
import '../../providers/auth_providers.dart';
import '../../providers/group_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../shell/widgets/coming_soon_view.dart';
import 'group_chat_screen.dart';
import 'group_detail_screen.dart';
import 'widgets/group_card.dart';
import 'widgets/groups_hero_header.dart';
import 'widgets/request_group_sheet.dart';
import '../discovery/widgets/discovery_error_view.dart';
import '../../widgets/shimmer.dart';

/// The Groups tab: search and filter, then two tabs — "My groups" (the
/// ones you're in, unread chats first) and "Discover" (the rest, your
/// city's first). Join / leave inline, or open a group's page or chat.
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen>
    with SingleTickerProviderStateMixin {
  static const _debounceDuration = Duration(milliseconds: 400);

  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      ref.read(groupsFiltersProvider.notifier).setSearch(value);
    });
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
                  ChoiceChip(
                    key: const Key('group-category-all'),
                    label: const Text('All'),
                    selected: selected == null,
                    onSelected: (_) {
                      ref
                          .read(groupsFiltersProvider.notifier)
                          .setCategory(null);
                      Navigator.of(context).pop();
                    },
                  ),
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
    final selectedCategory = ref.watch(groupsFiltersProvider).category;
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final userName = currentUser?.name ?? '?';
    final myCount = ref
        .watch(groupsTabListProvider(GroupsTab.mine))
        .valueOrNull
        ?.total;
    // The real, admin-managed list (already sorted by name on the backend).
    final categoryNames =
        ref
            .watch(groupCategoriesProvider)
            .valueOrNull
            ?.map((c) => c.name)
            .toList() ??
        const <String>[];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          GroupsHeroHeader(
            userName: userName,
            avatarUrl: currentUser?.avatarUrl,
            onAvatarTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            onNotificationsTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: const InputDecoration(
                      hintText: 'Search groups',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  key: const Key('group-filter-button'),
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
          if (selectedCategory != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: InputChip(
                  key: const Key('group-active-category'),
                  label: Text(selectedCategory),
                  avatar: const Icon(Icons.filter_list, size: 16),
                  onDeleted: () => ref
                      .read(groupsFiltersProvider.notifier)
                      .setCategory(null),
                ),
              ),
            ),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.label,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            tabs: [
              Tab(
                key: const Key('groups-tab-mine'),
                text: myCount == null ? 'My groups' : 'My groups ($myCount)',
              ),
              const Tab(key: Key('groups-tab-discover'), text: 'Discover'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _GroupsTabList(
                  tab: GroupsTab.mine,
                  onDiscover: () => _tabController.animateTo(1),
                ),
                const _GroupsTabList(tab: GroupsTab.discover),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tab's list, with its own paging, pull-to-refresh and empty state.
class _GroupsTabList extends ConsumerStatefulWidget {
  const _GroupsTabList({required this.tab, this.onDiscover});

  final GroupsTab tab;

  /// "Discover groups" on an empty My groups tab.
  final VoidCallback? onDiscover;

  @override
  ConsumerState<_GroupsTabList> createState() => _GroupsTabListState();
}

class _GroupsTabListState extends ConsumerState<_GroupsTabList>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  int? _busyGroupId;

  GroupsTab get _otherTab =>
      widget.tab == GroupsTab.mine ? GroupsTab.discover : GroupsTab.mine;

  GroupsListNotifier get _notifier =>
      ref.read(groupsTabListProvider(widget.tab).notifier);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >
          _scrollController.position.maxScrollExtent - 200) {
        _notifier.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// A group changed tabs — drop it here and reload the other tab.
  void _moved(int groupId) {
    _notifier.removeGroup(groupId);
    ref.invalidate(groupsTabListProvider(_otherTab));
    if (ref.exists(groupsListProvider)) ref.invalidate(groupsListProvider);
  }

  Future<void> _join(Group group) => _changeMembership(group.id, () async {
    if (await _notifier.joinGroup(group.id)) _moved(group.id);
  });

  /// Leaving is one tap in the ⋮ menu, so it asks first.
  Future<void> _leave(Group group) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Leave ${group.name}?'),
        content: Text(
          group.isPrivate
              ? 'It\'s a private group — to come back you\'ll need to ask '
                    'to join again.'
              : 'You can join again any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            key: const Key('confirm-leave-group'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _changeMembership(group.id, () async {
      await _notifier.leaveGroup(group.id);
      _moved(group.id);
    });
  }

  Future<void> _changeMembership(
    int groupId,
    Future<void> Function() change,
  ) async {
    setState(() => _busyGroupId = groupId);
    try {
      await change();
    } on ApiException catch (e) {
      // e.g. a group's creator can't leave it — say why instead of
      // silently stopping the spinner.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busyGroupId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final groupsAsync = ref.watch(groupsTabListProvider(widget.tab));
    final isMine = widget.tab == GroupsTab.mine;

    return RefreshIndicator(
      onRefresh: () => _notifier.refresh(),
      child: groupsAsync.when(
        loading: () => const ShimmerCardList(),
        error: (error, _) => ListView(
          children: [
            const SizedBox(height: 40),
            DiscoveryErrorView(error: error, onRetry: _notifier.refresh),
          ],
        ),
        data: (state) {
          final groups = state.groups;
          if (groups.isEmpty) {
            return ListView(
              padding: const EdgeInsets.only(top: 24, bottom: 24),
              children: [
                ComingSoonView(
                  icon: Icons.groups_outlined,
                  title: isMine ? 'No groups yet' : 'No groups found',
                  message: isMine
                      ? 'Join a few to chat and share with growers near you.'
                      : 'Try a different search, or ask for a new group.',
                ),
                if (isMine && widget.onDiscover != null)
                  Center(
                    child: FilledButton(
                      key: const Key('groups-empty-discover'),
                      onPressed: widget.onDiscover,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                      ),
                      child: const Text('Discover groups'),
                    ),
                  ),
                if (!isMine) const RequestGroupFooter(),
              ],
            );
          }

          final nearYou = !isMine && (groups.first.isLocal ?? false);
          return ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(top: 6, bottom: 24),
            itemCount:
                groups.length +
                (nearYou ? 1 : 0) +
                (state.hasMore ? 1 : 0) +
                (isMine ? 0 : 1),
            itemBuilder: (context, index) {
              if (nearYou) {
                if (index == 0) {
                  return const _SectionHeading(
                    key: Key('groups-near-you'),
                    title: 'Near you first',
                    subtitle: 'Groups for your area, then the most popular',
                  );
                }
                index -= 1;
              }
              if (index >= groups.length) {
                if (state.hasMore && index == groups.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return const RequestGroupFooter();
              }

              final group = groups[index];
              return GroupCard(
                group: group,
                isBusy: _busyGroupId == group.id,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GroupDetailScreen(group: group),
                  ),
                ),
                onJoin: () => _join(group),
                onLeave: () => _leave(group),
                onOpenChat: () {
                  _notifier.markChatRead(group.id);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GroupChatScreen(group: group),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}
