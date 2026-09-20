import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/discovery_providers.dart';
import '../../providers/post_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/safety_actions.dart';
import '../../widgets/user_avatar.dart';
import '../home/post_detail_screen.dart';
import '../home/widgets/post_card.dart';
import 'listing_detail_screen.dart';
import 'widgets/listing_card.dart';

/// A grower's public profile — the app-wide destination whenever someone
/// taps another user's avatar or name (a post/comment author, event host,
/// group member, message sender, listing seller, etc.), not just from a
/// listing. Real GET /users/{id} + /users/{id}/listings — every field shown
/// here (verification, growing setup, experience level, rating, member
/// since, active listings) is a real account attribute; there's no
/// messaging/follow feature here beyond what a listing's own offer flow
/// already provides. "Active Listings" stays even for a non-seller — an
/// empty, truthful state ("No active listings right now") rather than
/// hiding the section conditionally.
class SellerProfileScreen extends ConsumerWidget {
  const SellerProfileScreen({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    final listingsAsync = ref.watch(userListingsProvider(userId));
    final postsAsync = ref.watch(authorPostsProvider(userId));
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;
    final viewedUser = profileAsync.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (viewedUser != null && viewedUser.id != currentUserId)
            UserSafetyMenuButton(
              userId: viewedUser.id,
              userName: viewedUser.name,
              closeAfterBlock: true,
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (user) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(userProfileProvider(userId));
              ref.invalidate(userListingsProvider(userId));
              await ref.read(authorPostsProvider(userId).notifier).refresh();
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: UserAvatar(
                    name: user.name,
                    avatarUrl: user.avatarUrl,
                    radius: 36,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        user.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (user.isVerified ?? false) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ],
                ),
                if (user.isVerified ?? false)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Center(
                      child: Text(
                        'Identity Verified',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'Member since ${_monthYear(user.createdAt)}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (user.growingSetup != null)
                      Chip(
                        avatar: const Icon(Icons.yard_outlined, size: 16),
                        label: Text('${user.growingSetup!.label} Grower'),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (user.experienceLevel != null)
                      Chip(
                        avatar: const Icon(Icons.eco_outlined, size: 16),
                        label: Text(user.experienceLevel!.label),
                        visualDensity: VisualDensity.compact,
                      ),
                    if (user.ratingAvg > 0)
                      Chip(
                        avatar: const Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        label: Text(user.ratingAvg.toStringAsFixed(1)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Posts',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                postsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('$error'),
                  ),
                  data: (posts) {
                    if (posts.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          "Hasn't posted anything yet.",
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final post in posts)
                          PostCard(
                            post: post,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => PostDetailScreen(post: post),
                              ),
                            ),
                            onLike: () => ref
                                .read(authorPostsProvider(userId).notifier)
                                .toggleLike(post),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  'Active Listings',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                listingsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text('$error'),
                  ),
                  data: (listings) {
                    if (listings.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No active listings right now.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final listing in listings)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: ListingCard(
                              listing: listing,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ListingDetailScreen(listing: listing),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static String _monthYear(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
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
