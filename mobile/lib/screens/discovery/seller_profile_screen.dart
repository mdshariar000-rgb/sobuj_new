import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/app_config.dart';
import '../../models/app_user.dart';
import '../../models/enums.dart';
import '../../models/listing.dart';
import '../../providers/auth_providers.dart';
import '../../providers/discovery_providers.dart';
import '../../providers/post_providers.dart';
import '../../providers/safety_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/safety_actions.dart';
import '../../widgets/user_avatar.dart';
import '../home/post_detail_screen.dart';
import '../home/widgets/feed_listing_cards.dart';
import '../home/widgets/post_card.dart';
import '../profile/edit_profile_screen.dart';
import 'listing_detail_screen.dart';
import 'user_list_screen.dart';
import 'widgets/listing_thumbnail.dart';
import '../../widgets/image_decode.dart';
import '../../widgets/shimmer.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _monthYear(DateTime date) => '${_months[date.month - 1]} ${date.year}';

/// A grower's public profile — the app-wide destination whenever someone
/// taps another user's avatar or name (a post/comment author, event host,
/// group member, message sender, listing seller, etc.). Real GET /users/{id}
/// + /users/{id}/listings + their Home feed posts; every number shown is a
/// real count, and trust signals (rating, completed deals) only appear once
/// there's something to show.
class SellerProfileScreen extends ConsumerStatefulWidget {
  const SellerProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  ConsumerState<SellerProfileScreen> createState() =>
      _SellerProfileScreenState();
}

class _SellerProfileScreenState extends ConsumerState<SellerProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _share(AppUser user) {
    final role = _roleLine(user);
    SharePlus.instance.share(
      ShareParams(
        text: [
          '${user.name} on Shobuj',
          ?role,
          if (user.bio != null && user.bio!.isNotEmpty) user.bio!,
          AppConfig.profileShareUrl(user.id),
        ].join('\n'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider(widget.userId));
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;

    return profileAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const ShimmerProfile(),
      ),
      error: (error, _) {
        // A block hides the profile (the API 404s it), so if this is someone
        // the user blocked, offer Unblock here rather than a dead end.
        final blocked = ref
            .watch(blockedUsersProvider)
            .valueOrNull
            ?.where((u) => u.id == widget.userId)
            .firstOrNull;
        if (blocked != null) {
          return _BlockedProfileView(user: blocked, userId: widget.userId);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Profile')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                error is ApiException
                    ? error.message
                    : 'Could not load profile.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
      data: (user) {
        final isSelf = user.id == currentUserId;
        return Scaffold(
          backgroundColor: AppColors.surface,
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.forestDark,
                foregroundColor: Colors.white,
                // The theme's title style carries its own dark color, which
                // beats foregroundColor — set white explicitly.
                titleTextStyle: Theme.of(
                  context,
                ).appBarTheme.titleTextStyle?.copyWith(color: Colors.white),
                title: Text(user.name, overflow: TextOverflow.ellipsis),
                actions: [
                  IconButton(
                    key: const Key('share-profile-button'),
                    icon: const Icon(Icons.ios_share),
                    tooltip: 'Share profile',
                    onPressed: () => _share(user),
                  ),
                  if (!isSelf)
                    UserSafetyMenuButton(
                      userId: user.id,
                      userName: user.name,
                      closeAfterBlock: true,
                      iconColor: Colors.white,
                    ),
                ],
              ),
              SliverToBoxAdapter(
                child: _ProfileHeader(
                  user: user,
                  isSelf: isSelf,
                  onShowPosts: () => _tabController.animateTo(0),
                  onShowListings: () => _tabController.animateTo(1),
                  onShare: () => _share(user),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.label,
                    indicatorColor: AppColors.primary,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                    tabs: const [
                      Tab(
                        key: Key('profile-posts-tab'),
                        icon: Icon(Icons.grid_view_rounded, size: 20),
                        text: 'Posts',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                      Tab(
                        key: Key('profile-listings-tab'),
                        icon: Icon(Icons.storefront_outlined, size: 20),
                        text: 'Listings',
                        iconMargin: EdgeInsets.only(bottom: 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _PostsTab(userId: user.id),
                _ListingsTab(userId: user.id),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Shown in place of a profile the user has blocked: who it is, and an
/// Unblock button that reloads the real profile once it succeeds.
class _BlockedProfileView extends ConsumerStatefulWidget {
  const _BlockedProfileView({required this.user, required this.userId});

  final AppUser user;
  final int userId;

  @override
  ConsumerState<_BlockedProfileView> createState() =>
      _BlockedProfileViewState();
}

class _BlockedProfileViewState extends ConsumerState<_BlockedProfileView> {
  bool _unblocking = false;

  Future<void> _unblock() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _unblocking = true);
    try {
      await unblockUser(context, widget.user.id);
      ref.invalidate(userProfileProvider(widget.userId));
      messenger.showSnackBar(
        SnackBar(content: Text('Unblocked ${widget.user.name}.')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _unblocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Scaffold(
      appBar: AppBar(title: Text(user.name, overflow: TextOverflow.ellipsis)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(
                name: user.name,
                avatarUrl: user.avatarUrl,
                radius: 40,
              ),
              const SizedBox(height: 16),
              Text(
                "You've blocked ${user.name}",
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                "You won't see their posts, listings or messages until you "
                'unblock them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('unblock-profile-button'),
                onPressed: _unblocking ? null : _unblock,
                child: _unblocking
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Unblock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Hydroponic Grower · Intermediate" — from the user's own profile
/// answers; null when they haven't set either.
String? _roleLine(AppUser user) {
  final parts = [
    if (user.growingSetup != null) '${user.growingSetup!.label} Grower',
    ?user.experienceLevel?.label,
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.isSelf,
    required this.onShowPosts,
    required this.onShowListings,
    required this.onShare,
  });

  final AppUser user;
  final bool isSelf;
  final VoidCallback onShowPosts;
  final VoidCallback onShowListings;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVerified = user.isVerified ?? false;
    final role = _roleLine(user);
    final location = user.locationLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _Cover(url: user.coverPhotoUrl),
            Positioned(
              left: 20,
              bottom: -46,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: UserAvatar(
                  name: user.name,
                  avatarUrl: user.avatarUrl,
                  radius: 46,
                ),
              ),
            ),
            if (isVerified)
              const Positioned(right: 16, bottom: -18, child: _VerifiedPill()),
          ],
        ),
        const SizedBox(height: 56),
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
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                  if (isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ],
                ],
              ),
              if (user.username != null && user.username!.isNotEmpty)
                Text(
                  '@${user.username}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              if (role != null) ...[
                const SizedBox(height: 8),
                _MetaLine(icon: Icons.yard_outlined, text: role, strong: true),
              ],
              const SizedBox(height: 4),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  if (location != null && location.isNotEmpty)
                    _MetaLine(icon: Icons.place_outlined, text: location),
                  _MetaLine(
                    icon: Icons.calendar_today_outlined,
                    text: 'Joined ${_monthYear(user.createdAt)}',
                  ),
                ],
              ),
              if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  user.bio!.trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                ),
              ],
              _TrustBadges(user: user),
              const SizedBox(height: 16),
              _StatsCard(
                user: user,
                onShowPosts: onShowPosts,
                onShowListings: onShowListings,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: isSelf
                        ? OutlinedButton.icon(
                            key: const Key('edit-own-profile-button'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EditProfileScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: const Text('Edit profile'),
                          )
                        : _FollowButton(
                            userId: user.id,
                            isFollowing: user.isFollowing ?? false,
                          ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: onShare,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(52, 52),
                      ),
                      child: const Icon(Icons.share_outlined, size: 20),
                    ),
                  ),
                ],
              ),
              if (user.growingInterests.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'GROWS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final interest in user.growingInterests)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.mint.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          interest,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.forestDark,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

/// Their own cover photo, or a quiet branded banner when they haven't set
/// one.
class _Cover extends StatelessWidget {
  const _Cover({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    const height = 150.0;
    final fallback = Container(
      height: height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forestDark, AppColors.forestPanel],
        ),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Icon(
            Icons.eco_rounded,
            size: 110,
            color: AppColors.mint.withValues(alpha: 0.12),
          ),
        ),
      ),
    );

    if (url == null) return fallback;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CachedNetworkImage(
        imageUrl: url!,
        memCacheWidth: decodeWidthFor(context, double.infinity),
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 16, color: AppColors.primary),
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
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    this.strong = false,
  });

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: strong ? AppColors.primary : AppColors.textMuted,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: strong ? AppColors.textDark : AppColors.textMuted,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}

/// Rating from buyers and completed deals — only the ones that exist, so a
/// new grower's profile isn't padded with zeros.
class _TrustBadges extends StatelessWidget {
  const _TrustBadges({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final reviews = user.sellerReviewsCount ?? 0;
    final deals = user.completedDealsCount ?? 0;
    final badges = [
      if (user.sellerRating != null && reviews > 0)
        _TrustBadge(
          key: const Key('profile-rating-badge'),
          icon: Icons.star_rounded,
          iconColor: Colors.amber.shade700,
          text:
              '${user.sellerRating!.toStringAsFixed(1)} · '
              '$reviews review${reviews == 1 ? '' : 's'}',
        ),
      if (deals > 0)
        _TrustBadge(
          key: const Key('profile-deals-badge'),
          icon: Icons.handshake_outlined,
          iconColor: AppColors.primary,
          text: '$deals deal${deals == 1 ? '' : 's'} completed',
        ),
    ];
    if (badges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: badges),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Posts · Listings · Followers · Following in one card. Posts/Listings
/// jump to their tab; Followers/Following open the lists.
class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.user,
    required this.onShowPosts,
    required this.onShowListings,
  });

  final AppUser user;
  final VoidCallback onShowPosts;
  final VoidCallback onShowListings;

  @override
  Widget build(BuildContext context) {
    void openList(
      String title,
      AutoDisposeFutureProvider<List<AppUser>> provider,
      String empty,
    ) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => UserListScreen(
            title: title,
            provider: provider,
            emptyMessage: empty,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _StatCell(
              count: user.postsCount,
              label: 'Posts',
              onTap: onShowPosts,
            ),
            const VerticalDivider(width: 1),
            _StatCell(
              count: user.activeListingsCount,
              label: 'Listings',
              onTap: onShowListings,
            ),
            const VerticalDivider(width: 1),
            _StatCell(
              count: user.followersCount ?? 0,
              label: 'Followers',
              onTap: () => openList(
                'Followers',
                userFollowersProvider(user.id),
                '${user.name} has no followers yet.',
              ),
            ),
            const VerticalDivider(width: 1),
            _StatCell(
              count: user.followingCount ?? 0,
              label: 'Following',
              onTap: () => openList(
                'Following',
                userFollowingProvider(user.id),
                "${user.name} isn't following anyone yet.",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.count,
    required this.label,
    required this.onTap,
  });

  /// Null when the backend didn't send it — shown as a dash, not a fake 0.
  final int? count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count?.toString() ?? '–',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Follow / Unfollow — optimistic toggle via UserProfileNotifier, rolled
/// back on failure with a snackbar.
class _FollowButton extends ConsumerStatefulWidget {
  const _FollowButton({required this.userId, required this.isFollowing});

  final int userId;
  final bool isFollowing;

  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool _isToggling = false;

  Future<void> _toggle() async {
    setState(() => _isToggling = true);
    try {
      await ref
          .read(userProfileProvider(widget.userId).notifier)
          .toggleFollow();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = _isToggling ? null : _toggle;
    const size = Size.fromHeight(52);

    return widget.isFollowing
        ? OutlinedButton.icon(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(minimumSize: size),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Following'),
          )
        : FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(minimumSize: size),
            icon: const Icon(Icons.person_add_alt_1, size: 18),
            label: const Text('Follow'),
          );
  }
}

class _PostsTab extends ConsumerWidget {
  const _PostsTab({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(authorPostsProvider(userId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userProfileProvider(userId));
        await ref.read(authorPostsProvider(userId).notifier).refresh();
      },
      child: postsAsync.when(
        loading: () => const ShimmerPostList(),
        error: (error, _) => _TabMessage(
          icon: Icons.wifi_off,
          text: error is ApiException ? error.message : 'Could not load posts.',
        ),
        data: (posts) {
          if (posts.isEmpty) {
            return const _TabMessage(
              icon: Icons.article_outlined,
              text: "Hasn't posted anything yet.",
            );
          }
          return ListView.builder(
            key: const PageStorageKey('profile-posts'),
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              return PostCard(
                post: post,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(post: post),
                  ),
                ),
                onLike: () => ref
                    .read(authorPostsProvider(userId).notifier)
                    .toggleLike(post),
              );
            },
          );
        },
      ),
    );
  }
}

class _ListingsTab extends ConsumerWidget {
  const _ListingsTab({required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingsAsync = ref.watch(userListingsProvider(userId));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userProfileProvider(userId));
        return ref.refresh(userListingsProvider(userId).future);
      },
      child: listingsAsync.when(
        loading: () => const ShimmerListingGrid(rows: 2),
        error: (error, _) => _TabMessage(
          icon: Icons.wifi_off,
          text: error is ApiException
              ? error.message
              : 'Could not load listings.',
        ),
        data: (listings) {
          if (listings.isEmpty) {
            return const _TabMessage(
              icon: Icons.storefront_outlined,
              text: 'No active listings right now.',
            );
          }
          return ListView.separated(
            key: const PageStorageKey('profile-listings'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: listings.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) =>
                _ListingRow(listing: listings[index]),
          );
        },
      ),
    );
  }
}

/// One listing as a detailed row: photo with its deal-type badge, then
/// title, price, category/condition, a short description, and when it was
/// posted. Rating only shows when the API included it.
class _ListingRow extends StatelessWidget {
  const _ListingRow({required this.listing});

  static const _photoSize = 96.0;

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFree = listing.transactionType == TransactionType.free;
    final details = [
      listing.listingType,
      if (listing.condition != null) listing.condition!.label,
    ].join(' · ');
    final description = listing.description?.trim();
    final rating = listing.averageRating;
    final reviewsCount = listing.reviewsCount ?? 0;

    return Material(
      key: Key('profile-listing-${listing.id}'),
      color: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ListingDetailScreen(listing: listing),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ListingThumbnail(
                    url: listing.thumbnailUrl,
                    size: _photoSize,
                    height: _photoSize,
                    borderRadius: 10,
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isFree
                            ? AppColors.mint
                            : AppColors.forestDark.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        listing.transactionType.isRequest
                            ? 'Wanted'
                            : listing.transactionType.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isFree ? AppColors.textDark : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      feedListingPriceLabel(listing),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (description != null && description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (rating != null && reviewsCount > 0) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${rating.toStringAsFixed(1)} ($reviewsCount)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        const Icon(
                          Icons.schedule,
                          size: 13,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            timeago.format(listing.createdAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An empty or error state inside a tab — scrollable so pull-to-refresh
/// still works on it.
class _TabMessage extends StatelessWidget {
  const _TabMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      children: [
        Icon(icon, size: 40, color: AppColors.textMuted.withValues(alpha: 0.6)),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted),
        ),
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
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}

/// The shared entry point used everywhere in the app someone taps another
/// user's avatar or name (a post/comment author, event host, group member,
/// message sender, listing seller, etc.) — a no-op when [userId] is null
/// (e.g. a relation that failed to load), rather than crashing or opening a
/// broken screen.
void openUserProfile(BuildContext context, int? userId) {
  if (userId == null) return;
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => SellerProfileScreen(userId: userId)),
  );
}
