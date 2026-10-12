import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/listing.dart';
import '../../providers/auth_providers.dart';
import '../../providers/feed_marketplace_providers.dart';
import '../../providers/search_providers.dart';
import '../../providers/shell_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../discovery/discovery_screen.dart';
import '../discovery/listing_detail_screen.dart';
import '../discovery/widgets/message_seller.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../shell/widgets/coming_soon_view.dart';
import 'search_results_screen.dart';
import 'search_screen.dart';
import 'widgets/home_hero_header.dart';
import 'widgets/quick_access_section.dart';
import '../../widgets/shimmer.dart';

/// The Home tab: search across items, places and members, quick-access
/// shortcuts, and a grid of marketplace listings picked for the user.
/// How many listings "Picked for you" shows before "See all".
const _pickedForYouCount = 6;

/// The Marketplace's bottom-nav tab — see AgroHubShell.
const _marketplaceTabIndex = 3;

class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  void _search(String value) {
    final term = value.trim();
    if (term.length < 2) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SearchResultsScreen(term: term)));
  }

  Future<void> _toggleSave(Listing listing) async {
    try {
      await ref.read(feedMarketplaceProvider.notifier).toggleSaved(listing);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final marketplaceAsync = ref.watch(feedMarketplaceProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: RefreshIndicator(
        onRefresh: () => ref.read(feedMarketplaceProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: HomeHeroHeader(
                userName: currentUser?.name ?? 'Grower',
                avatarUrl: currentUser?.avatarUrl,
                onAvatarTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                onNotificationsTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                // Opens the full-screen search, which suggests as you type.
                child: TextField(
                  key: const Key('home-search-field'),
                  readOnly: true,
                  showCursor: false,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Search items, people, places',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _RecentSearches(onSearch: _search)),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 16, bottom: 20),
                child: QuickAccessSection(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Picked for you',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      key: const Key('picked-for-you-see-all'),
                      onPressed: () =>
                          ref.read(selectedTabIndexProvider.notifier).state =
                              _marketplaceTabIndex,
                      style: TextButton.styleFrom(minimumSize: Size.zero),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),
            marketplaceAsync.when(
              loading: () =>
                  const SliverToBoxAdapter(child: ShimmerListingGrid(rows: 2)),
              error: (error, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text('$error', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref
                            .read(feedMarketplaceProvider.notifier)
                            .refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (marketplace) {
                final seenIds = <int>{};
                final listings = <Listing>[
                  // Matches for past searches first, then what's nearby.
                  for (final listing in [
                    ...marketplace.forYou,
                    ...marketplace.nearby,
                    ...marketplace.fromFollowing,
                  ])
                    if (seenIds.add(listing.id)) listing,
                ];
                if (listings.isEmpty) {
                  return const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: ComingSoonView(
                        icon: Icons.storefront_outlined,
                        title: 'Nothing near you yet',
                        message:
                            'New marketplace listings near you will show up here.',
                      ),
                    ),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  // Same cards as the Marketplace tab — a short taster;
                  // "See all" opens the rest there.
                  sliver: ListingGrid(
                    listings: listings.take(_pickedForYouCount).toList(),
                    onTap: (listing) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ListingDetailScreen(listing: listing),
                      ),
                    ),
                    onChat: (listing) =>
                        currentUser != null &&
                            listing.owner?.id == currentUser.id
                        ? null
                        : () => messageSeller(context, ref, listing),
                    onToggleSave: (listing) => _toggleSave(listing),
                  ),
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

/// The user's last few searches as chips under the search bar — tap one to
/// run it again.
class _RecentSearches extends ConsumerWidget {
  const _RecentSearches({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = ref.watch(searchHistoryProvider).valueOrNull ?? const [];
    if (terms.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: terms.take(8).length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ActionChip(
          key: Key('recent-search-${terms[index]}'),
          avatar: const Icon(Icons.history, size: 16),
          label: Text(terms[index]),
          onPressed: () => onSearch(terms[index]),
        ),
      ),
    );
  }
}
