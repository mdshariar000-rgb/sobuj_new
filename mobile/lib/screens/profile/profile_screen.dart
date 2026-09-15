import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/app_user.dart';
import '../../models/enums.dart';
import '../../models/listing.dart';
import '../../providers/auth_providers.dart';
import '../../providers/discovery_providers.dart';
import '../../providers/post_providers.dart';
import '../../providers/shell_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_avatar.dart';
import '../discovery/listing_detail_screen.dart';
import '../home/widgets/post_card.dart';
import 'edit_profile_screen.dart';
import 'manage_subscription_screen.dart';

/// The Profile tab: the signed-in user's own details, posts, and listings.
/// Every field is real — see AppUser/UserResource; there is no Connections
/// count, Story button, or "Saved Diagnoses" tab, since none of those exist
/// on the backend (no follower graph, no Stories feature, no AI-diagnosis
/// save flow).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.forestDark,
            foregroundColor: Colors.white,
            title: const Text('Profile'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Log out',
                onPressed: () {
                  Navigator.of(context).pop();
                  ref.read(authControllerProvider.notifier).logout();
                },
              ),
            ],
          ),
          SliverToBoxAdapter(child: _ProfileHeader(user: user)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.label,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(
                    child: _ProfileTabLabel(
                      label: 'My Posts',
                      count: user.postsCount,
                      isActive: _tabController.index == 0,
                    ),
                  ),
                  Tab(
                    child: _ProfileTabLabel(
                      label: 'My Listings',
                      count: user.activeListingsCount,
                      isActive: _tabController.index == 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _MyPostsTab(userId: user.id),
            const _MyListingsTab(),
          ],
        ),
      ),
    );
  }
}

/// Rebuilt as a StatefulWidget body wrapper so the TabBarView (which needs
/// a bounded, scrollable-per-tab area) can live below the sliver header.
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user});

  final AppUser user;

  void _editProfile(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const EditProfileScreen()),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVerified = user.isVerified ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 176,
              width: double.infinity,
              color: AppColors.forestPanel,
              child: user.coverPhotoUrl != null
                  ? CachedNetworkImage(
                      imageUrl: user.coverPhotoUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    )
                  : null,
            ),
            Positioned(
              right: 12,
              top: 12,
              child: _EditCoverButton(onTap: () => _editProfile(context)),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: -44,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => _editProfile(context),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                          ),
                          child: UserAvatar(
                            name: user.name,
                            avatarUrl: user.avatarUrl,
                            radius: 48,
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 4,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.surface,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 13,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (isVerified)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Verified Grower',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 52),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ],
                ],
              ),
              if (user.username != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '@${user.username}',
                    style: const TextStyle(
                      color: AppColors.label,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (user.bio != null && user.bio!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(user.bio!),
                ),
              if (user.postsCount != null ||
                  user.activeListingsCount != null ||
                  (user.locationLabel?.isNotEmpty ?? false))
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.border),
                      bottom: BorderSide(color: AppColors.border),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user.postsCount != null ||
                          user.activeListingsCount != null)
                        Row(
                          children: [
                            if (user.postsCount != null)
                              _StatInline(
                                icon: Icons.article_outlined,
                                value: user.postsCount!,
                                label: 'Posts',
                              ),
                            if (user.postsCount != null &&
                                user.activeListingsCount != null)
                              const SizedBox(width: 20),
                            if (user.activeListingsCount != null)
                              _StatInline(
                                icon: Icons.storefront_outlined,
                                value: user.activeListingsCount!,
                                label: 'Active Listings',
                              ),
                          ],
                        ),
                      if (user.locationLabel != null &&
                          user.locationLabel!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  user.locationLabel!,
                                  style: const TextStyle(
                                    color: AppColors.label,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _editProfile(context),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Profile'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        final buffer = StringBuffer(
                          '${user.name} is on Agro Hub',
                        );
                        if (user.username != null) {
                          buffer.write(' (@${user.username})');
                        }
                        SharePlus.instance.share(
                          ShareParams(text: buffer.toString()),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.buttonMuted,
                        foregroundColor: AppColors.textDark,
                      ),
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const _ManageSubscriptionRow(),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ManageSubscriptionRow extends StatelessWidget {
  const _ManageSubscriptionRow();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ManageSubscriptionScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.mint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.spa,
                size: 16,
                color: AppColors.forestDark,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Manage Subscription',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditCoverButton extends StatelessWidget {
  const _EditCoverButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.forestPanel,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, size: 13, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Edit Cover',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatInline extends StatelessWidget {
  const _StatInline({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          '$value',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(color: AppColors.label, fontSize: 12),
        ),
      ],
    );
  }
}

class _MyPostsTab extends ConsumerWidget {
  const _MyPostsTab({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(authorPostsProvider(userId));

    return postsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (posts) {
        return RefreshIndicator(
          onRefresh: () => ref.read(authorPostsProvider(userId).notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: posts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _GroupsPromptCard(
                  onTap: () {
                    ref.read(selectedTabIndexProvider.notifier).state = 1;
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                );
              }
              if (posts.isEmpty && index == 1) {
                return const _EmptyTabState(
                  icon: Icons.article_outlined,
                  message: "You haven't posted anything yet.",
                );
              }
              final post = posts[index - 1];
              return PostCard(
                post: post,
                onLike: () =>
                    ref.read(authorPostsProvider(userId).notifier).toggleLike(post),
              );
            },
          ),
        );
      },
    );
  }
}

/// A simple, honest nudge toward Groups — the reference image's fabricated
/// engagement banner replaced with a real navigation shortcut rather than
/// an invented "posts from your groups" feed (no such aggregation endpoint
/// exists).
class _GroupsPromptCard extends StatelessWidget {
  const _GroupsPromptCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      color: AppColors.surfaceMuted,
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.groups_outlined, color: AppColors.primary),
        title: const Text('Looking for more?'),
        subtitle: const Text('See posts from the groups you have joined.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _MyListingsTab extends ConsumerWidget {
  const _MyListingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(myListingsProvider);

    return listingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('$error')),
      data: (listings) {
        if (listings.isEmpty) {
          return const _EmptyTabState(
            icon: Icons.storefront_outlined,
            message: "You haven't listed anything yet.",
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(myListingsProvider.notifier).refresh(),
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: listings.length,
            itemBuilder: (context, index) {
              final listing = listings[index];
              return _MyListingRow(
                listing: listing,
                onManage: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ListingDetailScreen(listing: listing),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _MyListingRow extends StatelessWidget {
  const _MyListingRow({required this.listing, required this.onManage});

  final Listing listing;
  final VoidCallback onManage;

  Color _statusColor() {
    switch (listing.status) {
      case ListingStatus.active:
        return AppColors.primary;
      case ListingStatus.reserved:
        return Colors.orange;
      case ListingStatus.completed:
        return AppColors.textMuted;
      case ListingStatus.deleted:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: listing.thumbnailUrl != null
                    ? Image.network(listing.thumbnailUrl!, fit: BoxFit.cover)
                    : Container(
                        color: AppColors.surfaceMuted,
                        child: const Icon(
                          Icons.eco_outlined,
                          color: AppColors.textMuted,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _statusColor().withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          listing.status.label,
                          style: TextStyle(
                            color: _statusColor(),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (listing.price != null)
                        Text(
                          NumberFormat.simpleCurrency().format(listing.price),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${listing.viewsCount} views',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: onManage, child: const Text('Manage')),
          ],
        ),
      ),
    );
  }
}

class _EmptyTabState extends StatelessWidget {
  const _EmptyTabState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTabLabel extends StatelessWidget {
  const _ProfileTabLabel({
    required this.label,
    required this.count,
    required this.isActive,
  });

  final String label;
  final int? count;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.buttonMuted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? Colors.white : AppColors.label,
              ),
            ),
          ),
        ],
      ],
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
