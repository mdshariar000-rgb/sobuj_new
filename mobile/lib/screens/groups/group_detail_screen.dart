import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/group.dart';
import '../../models/post.dart';
import '../../models/report.dart';
import '../../providers/auth_providers.dart';
import '../../providers/group_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/safety_actions.dart';
import '../../widgets/user_avatar.dart';
import '../discovery/seller_profile_screen.dart';
import '../home/post_detail_screen.dart';
import '../home/widgets/edit_post_sheet.dart';
import '../home/widgets/post_card.dart';
import 'create_group_post_screen.dart';
import 'group_chat_screen.dart';
import 'group_join_requests_screen.dart';
import 'group_settings_screen.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// A group's own page: header (cover/name/description/member count), real
/// Join/Leave + Invite (native share) + Group Chat actions, and three tabs —
/// All Posts (the async discussion thread), Media & Photos (posts with a
/// real photo attached), and Members (the real roster with real roles).
/// There is deliberately no "Files & Guides" tab (no attachment/file feature
/// exists) and no "Verified"/"Zone" badges (nothing real backs them).
class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  bool _isTogglingMembership = false;
  bool _isSearching = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// A public group joins/leaves instantly, same as always. A private group
  /// a user hasn't joined instead files/cancels a real request — see
  /// [Group.isPrivate]/[Group.joinRequestPending] and
  /// GroupController::join()/cancelJoinRequest() on the backend.
  Future<void> _toggleMembership(Group group) async {
    setState(() => _isTogglingMembership = true);
    try {
      final notifier = ref.read(groupDetailProvider(widget.group).notifier);
      if (group.isMember ?? false) {
        await notifier.leave();
      } else if (group.joinRequestPending ?? false) {
        await notifier.cancelJoinRequest();
      } else {
        await notifier.join();
      }
    } finally {
      if (mounted) setState(() => _isTogglingMembership = false);
    }
  }

  void _startSearch() {
    setState(() => _isSearching = true);
  }

  void _stopSearch() {
    _searchController.clear();
    setState(() {
      _isSearching = false;
      _searchQuery = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final groupAsync = ref.watch(groupDetailProvider(widget.group));
    final group = groupAsync.valueOrNull ?? widget.group;
    final isMember = group.isMember ?? false;

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: (isMember && _tabController.index == 0)
          ? FloatingActionButton.extended(
              heroTag: 'group-detail-create-post-${group.id}',
              backgroundColor: AppColors.mintButton,
              foregroundColor: AppColors.mintButtonText,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateGroupPostScreen(group: group),
                ),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Create Post'),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.forestDark,
            foregroundColor: Colors.white,
            titleSpacing: _isSearching ? 0 : null,
            title: _isSearching
                ? TextField(
                    key: const Key('group-detail-search-field'),
                    controller: _searchController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      hintText: 'Search posts in this group...',
                      hintStyle: TextStyle(color: AppColors.textOnDarkMuted),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.trim()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (group.isVerified ?? false) ...[
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              size: 15,
                              color: Colors.white,
                            ),
                          ],
                        ],
                      ),
                      if (group.membersCount != null)
                        Text(
                          '${_compactCount(group.membersCount!)} members',
                          style: const TextStyle(
                            color: AppColors.textOnDarkMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
            actions: [
              IconButton(
                key: const Key('group-detail-search-button'),
                onPressed: _isSearching ? _stopSearch : _startSearch,
                icon: Icon(_isSearching ? Icons.close : Icons.search),
              ),
              IconButton(
                onPressed: isMember
                    ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupChatScreen(group: group),
                        ),
                      )
                    : null,
                icon: const Icon(Icons.chat_bubble_outline),
                tooltip: 'Group Chat',
              ),
              if (!group.myRoleIsAdmin)
                IconButton(
                  key: const Key('group-report-button'),
                  onPressed: () => showReportSheet(
                    context,
                    target: ReportTarget.group,
                    targetId: group.id,
                  ),
                  icon: const Icon(Icons.flag_outlined),
                  tooltip: 'Report group',
                ),
              if (group.myRoleIsAdmin)
                IconButton(
                  key: const Key('group-detail-settings-button'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GroupSettingsScreen(group: group),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Group Settings',
                ),
            ],
          ),
          if (group.myRoleIsAdmin &&
              (group.pendingJoinRequestsCount ?? 0) > 0)
            SliverToBoxAdapter(
              child: _PendingRequestsBanner(group: group),
            ),
          SliverToBoxAdapter(
            child: _GroupHeader(
              group: group,
              isBusy: _isTogglingMembership,
              onToggleMembership: () => _toggleMembership(group),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('All Posts'),
                        if (group.postsCount != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _compactCount(group.postsCount!),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Tab(text: 'Media & Photos'),
                  const Tab(text: 'Members'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _AllPostsTab(group: group, searchQuery: _searchQuery),
            _MediaTab(groupId: group.id),
            _MembersTab(groupId: group.id),
          ],
        ),
      ),
    );
  }
}

/// Abbreviates a real count for display (e.g. 1234 -> "1.2K") — a display
/// transform of real data, not a fabricated number.
String _compactCount(int count) => NumberFormat.compact().format(count);

/// A real, tappable banner surfacing this group's pending join requests to
/// its admin — see GroupResource::pending_join_requests_count.
class _PendingRequestsBanner extends StatelessWidget {
  const _PendingRequestsBanner({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final count = group.pendingJoinRequestsCount ?? 0;

    return InkWell(
      key: const Key('group-detail-pending-requests-banner'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupJoinRequestsScreen(group: group),
        ),
      ),
      child: Container(
        color: AppColors.mint.withValues(alpha: 0.15),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.person_add_alt, color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count pending join ${count == 1 ? 'request' : 'requests'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.group,
    required this.isBusy,
    required this.onToggleMembership,
  });

  final Group group;
  final bool isBusy;
  final VoidCallback onToggleMembership;

  @override
  Widget build(BuildContext context) {
    final isMember = group.isMember ?? false;
    final joinRequestPending = group.joinRequestPending ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (group.coverImageUrl != null)
          Stack(
            children: [
              CachedNetworkImage(
                imageUrl: group.coverImageUrl!,
                width: double.infinity,
                height: 176,
                fit: BoxFit.cover,
              ),
              if (group.category != null)
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.forestPanel,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.eco_outlined,
                          size: 13,
                          color: AppColors.mint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          group.category!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Only a fallback for groups with no cover photo to overlay it
              // on — when there is one, the badge sits on the photo itself
              // above, matching the reference design.
              if (group.category != null && group.coverImageUrl == null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    group.category!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Flexible(
                    child: Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (group.isVerified ?? false) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${group.isPrivate ? 'Private Group' : 'Public Group'} · '
                'Est. ${_months[group.createdAt.month - 1]} ${group.createdAt.year}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              if (group.description != null) ...[
                const SizedBox(height: 12),
                Text(group.description!),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: isMember
                        ? _PillButton(
                            onPressed: isBusy ? null : onToggleMembership,
                            backgroundColor: AppColors.buttonMuted,
                            foregroundColor: AppColors.textDark,
                            icon: Icons.check,
                            label: 'Joined',
                          )
                        : joinRequestPending
                        ? _PillButton(
                            key: const Key('group-detail-request-pending'),
                            // Tapping withdraws the request — see
                            // GroupDetailNotifier.cancelJoinRequest().
                            onPressed: isBusy ? null : onToggleMembership,
                            backgroundColor: AppColors.buttonMuted,
                            foregroundColor: AppColors.textDark,
                            icon: Icons.hourglass_top,
                            label: 'Request Pending',
                          )
                        : _PillButton(
                            onPressed: isBusy ? null : onToggleMembership,
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            label: group.isPrivate
                                ? 'Request to Join'
                                : 'Join Group',
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PillButton(
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Join "${group.name}" on Agro Hub — '
                              '${group.membersCount ?? 0} growers so far.',
                        ),
                      ),
                      backgroundColor: AppColors.buttonMuted,
                      foregroundColor: AppColors.textDark,
                      icon: Icons.person_add_outlined,
                      label: 'Invite',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PillButton(
                      onPressed: isMember
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GroupChatScreen(group: group),
                              ),
                            )
                          : null,
                      backgroundColor: AppColors.mintButton,
                      foregroundColor: AppColors.mintButtonText,
                      icon: Icons.chat_bubble_outline,
                      label: 'Group Chat',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A radius-12 filled pill button (as opposed to the app-wide stadium
/// button theme) — matches the Group Detail action bar's Figma spec.
class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.label,
    this.icon,
  });

  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final child = icon == null
        ? Text(label, style: const TextStyle(fontWeight: FontWeight.w600))
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: backgroundColor.withValues(alpha: 0.5),
        disabledForegroundColor: foregroundColor.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      ),
      child: child,
    );
  }
}

class _AllPostsTab extends ConsumerWidget {
  const _AllPostsTab({required this.group, this.searchQuery = ''});

  final Group group;

  /// Filters the already-loaded posts client-side (real data, no separate
  /// search endpoint) — see the search icon in GroupDetailScreen's app bar.
  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(groupPostsProvider(group.id));
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;
    final currentUser = ref.watch(authControllerProvider).valueOrNull;

    Future<void> toggleLike(Post post) async {
      try {
        await ref.read(groupPostsProvider(group.id).notifier).toggleLike(post);
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(e.message)));
        }
      }
    }

    void editPost(Post post) {
      showEditPostSheet(
        context,
        post: post,
        onSubmit: (ref, body, category, image, removeImage) => ref
            .read(groupPostsProvider(group.id).notifier)
            .updatePost(
              post.id,
              body: body,
              category: category,
              image: image,
              removeImage: removeImage,
            ),
      );
    }

    Future<void> deletePost(int postId) async {
      if (!await confirmDeletePost(context) || !context.mounted) return;
      await ref.read(groupPostsProvider(group.id).notifier).deletePost(postId);
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(groupPostsProvider(group.id).notifier).refresh(),
      child: postsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (state) {
          final query = searchQuery.toLowerCase();
          final posts = query.isEmpty
              ? state.posts
              : state.posts
                    .where((post) => post.body.toLowerCase().contains(query))
                    .toList();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (group.isMember ?? false)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: InkWell(
                    key: const Key('group-detail-composer'),
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CreateGroupPostScreen(group: group),
                      ),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          name: currentUser?.name ?? '?',
                          avatarUrl: currentUser?.avatarUrl,
                          radius: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Text(
                              'Write something in the group...',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              if (posts.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    query.isEmpty
                        ? 'No posts yet — start the conversation.'
                        : 'No posts match "$searchQuery".',
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                )
              else ...[
                for (final post in posts)
                  PostCard(
                    post: post,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PostDetailScreen(post: post),
                      ),
                    ),
                    onEdit: post.author?.id == currentUserId
                        ? () => editPost(post)
                        : null,
                    onDelete: post.author?.id == currentUserId
                        ? () => deletePost(post.id)
                        : null,
                    onLike: () => toggleLike(post),
                    onApprove: group.myRoleIsAdmin && post.isPendingApproval
                        ? () => ref
                              .read(groupPostsProvider(group.id).notifier)
                              .approvePost(post.id)
                        : null,
                    onReject: group.myRoleIsAdmin && post.isPendingApproval
                        ? () => ref
                              .read(groupPostsProvider(group.id).notifier)
                              .rejectPost(post.id)
                        : null,
                  ),
                if (state.hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: state.isLoadingMore
                          ? const CircularProgressIndicator()
                          : OutlinedButton(
                              onPressed: () => ref
                                  .read(groupPostsProvider(group.id).notifier)
                                  .loadMore(),
                              child: const Text('Load more'),
                            ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A real, if simplified, "Media & Photos" view: the discussion posts that
/// have a real uploaded photo, filtered from whatever's already loaded on
/// the All Posts tab rather than a separate paginated endpoint.
class _MediaTab extends ConsumerWidget {
  const _MediaTab({required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(groupPostsProvider(groupId));

    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (state) {
        final withPhotos = state.posts
            .where((post) => post.imageUrl != null)
            .toList();
        if (withPhotos.isEmpty) {
          return const Center(
            child: Text(
              'No photos shared in this group yet.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: withPhotos.length,
          itemBuilder: (context, index) {
            final post = withPhotos[index];
            return InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
              ),
              child: CachedNetworkImage(
                imageUrl: post.imageUrl!,
                fit: BoxFit.cover,
              ),
            );
          },
        );
      },
    );
  }
}

class _MembersTab extends ConsumerWidget {
  const _MembersTab({required this.groupId});

  final int groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (members) {
        if (members.isEmpty) {
          return const Center(
            child: Text(
              'No members yet.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final roleLabel = member.isAdmin
                ? 'Admin'
                : member.growingSetup?.label ?? member.experienceLevel?.label;
            return ListTile(
              onTap: () => openUserProfile(context, member.id),
              leading: UserAvatar(name: member.name, avatarUrl: member.avatarUrl),
              title: Row(
                children: [
                  Flexible(
                    child: Text(member.name, overflow: TextOverflow.ellipsis),
                  ),
                  if (member.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, size: 14, color: AppColors.primary),
                  ],
                ],
              ),
              subtitle: member.username != null ? Text('@${member.username}') : null,
              trailing: roleLabel != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: member.isAdmin
                            ? AppColors.mint.withValues(alpha: 0.4)
                            : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.surface, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}
