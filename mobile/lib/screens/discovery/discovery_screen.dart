import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/enums.dart';
import '../../models/listing.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/discovery_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../profile/profile_screen.dart';
import 'create_listing_screen.dart';
import 'favorites_screen.dart';
import 'listing_detail_screen.dart';
import 'messages_screen.dart';
import 'swap_offer_thread_screen.dart';
import 'widgets/category_chips.dart';
import 'widgets/create_listing_banner.dart';
import 'widgets/discovery_error_view.dart';
import 'widgets/discovery_search_bar.dart';
import 'widgets/listing_card.dart';
import 'widgets/listing_map_view.dart';
import 'widgets/marketplace_hero_header.dart';

/// The Marketplace tab — Discovery, the pre-pivot listings feature,
/// reintroduced with a full redesign: real filtering, saving, and a
/// real "make an offer" flow against the existing swap-offer backend.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  Future<void> _toggleSave(Listing listing) async {
    try {
      await ref.read(nearbyListingsProvider.notifier).toggleSaved(listing);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Creates (or reopens, if one's already open) the swap offer against this
  /// listing and drops straight into its message thread — like tapping a
  /// contact opens a chat, rather than filling out a form first.
  Future<void> _makeOffer(Listing listing) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final offer = await apiClient.createSwapOffer(listing.id);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SwapOfferThreadScreen(swapOffer: offer),
          ),
        );
      }
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
    final listingsAsync = ref.watch(nearbyListingsProvider);
    final viewMode = ref.watch(viewModeProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final userName = currentUser?.name ?? '?';
    final openOfferCount =
        ref
            .watch(mySwapOffersProvider)
            .valueOrNull
            ?.where((offer) => offer.status.isOpen)
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton(
        heroTag: 'marketplace-fab',
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const CreateListingScreen())),
        tooltip: 'Post a listing',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          MarketplaceHeroHeader(
            userName: userName,
            avatarUrl: currentUser?.avatarUrl,
            openOfferCount: openOfferCount,
            onAvatarTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            onMessagesTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
            onFavoritesTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FavoritesScreen())),
          ),
          const DiscoverySearchBar(),
          const _TransactionTypeTabs(),
          const Divider(height: 1),
          Expanded(
            child: switch (viewMode) {
              DiscoveryViewMode.map => const ListingMapView(),
              // Everything below the format tabs scrolls together (same
              // pattern as Home/Events/Groups) — a fixed header this tall
              // otherwise leaves almost no room for the error/empty states.
              DiscoveryViewMode.list => RefreshIndicator(
                onRefresh: () =>
                    ref.read(nearbyListingsProvider.notifier).refresh(),
                // The category/banner/location chrome only makes sense once
                // there's actually a result set to filter — showing it above
                // a loading spinner or a location-permission error just
                // squeezes that content into whatever space is left over
                // (and on small screens, straight off it). Loading/error
                // get the full remaining height to themselves instead.
                child: CustomScrollView(
                  slivers: listingsAsync.when(
                    loading: () => const [
                      SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ],
                    error: (error, _) => [
                      SliverFillRemaining(
                        child: DiscoveryErrorView(
                          error: error,
                          onRetry: () => ref
                              .read(nearbyListingsProvider.notifier)
                              .refresh(),
                        ),
                      ),
                    ],
                    data: (listings) => [
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      const SliverToBoxAdapter(child: CategoryChips()),
                      const SliverToBoxAdapter(child: SizedBox(height: 12)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: CreateListingBanner(
                            onCreate: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreateListingScreen(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SliverToBoxAdapter(child: _LocationAndSortRow()),
                      const SliverToBoxAdapter(child: _FilterButton()),
                      if (listings.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 48,
                                  color: AppColors.textMuted,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'No listings found nearby. Try '
                                  'widening your search radius.',
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(top: 8, bottom: 88),
                          sliver: SliverList.builder(
                            itemCount: listings.length,
                            itemBuilder: (context, index) {
                              final listing = listings[index];
                              return ListingCard(
                                listing: listing,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ListingDetailScreen(listing: listing),
                                  ),
                                ),
                                onCta: () => _makeOffer(listing),
                                onToggleSave: () => _toggleSave(listing),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _TransactionTypeTabs extends ConsumerWidget {
  const _TransactionTypeTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      discoveryFiltersProvider.select((filters) => filters.transactionType),
    );

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _TabChip(
            label: 'All',
            selected: selected == null,
            onTap: () => ref
                .read(discoveryFiltersProvider.notifier)
                .selectTransactionType(null),
          ),
          for (final type in TransactionType.values) ...[
            const SizedBox(width: 8),
            _TabChip(
              label: _tabLabel(type),
              selected: selected == type,
              onTap: () => ref
                  .read(discoveryFiltersProvider.notifier)
                  .selectTransactionType(type),
            ),
          ],
        ],
      ),
    );
  }
}

/// Adds a parenthetical clarifier to the two transaction types whose plain
/// label alone doesn't make the underlying action obvious in a short tab.
String _tabLabel(TransactionType type) {
  return switch (type) {
    TransactionType.sell => 'For Sale (Sell)',
    TransactionType.wanted => 'Looking to Buy (Buy)',
    TransactionType.free => 'Free / Pay-It-Forward',
    _ => type.label,
  };
}

class _TabChip extends StatelessWidget {
  const _TabChip({
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
      selectedColor: AppColors.forestDark,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.label,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      backgroundColor: AppColors.buttonMuted,
      shape: const StadiumBorder(),
      side: BorderSide.none,
    );
  }
}

class _LocationAndSortRow extends ConsumerWidget {
  const _LocationAndSortRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(discoveryFiltersProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<double>(
              initialValue: filters.radiusKm,
              onSelected: (value) => ref
                  .read(discoveryFiltersProvider.notifier)
                  .setRadiusKm(value),
              itemBuilder: (context) => const [5, 10, 25, 50]
                  .map(
                    (km) => PopupMenuItem(
                      value: km.toDouble(),
                      child: Text('Within $km km'),
                    ),
                  )
                  .toList(),
              child: _DropdownPill(
                icon: Icons.place_outlined,
                label: 'Within ${filters.radiusKm.round()} km',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PopupMenuButton<DiscoverySort>(
              initialValue: filters.sort,
              onSelected: (value) =>
                  ref.read(discoveryFiltersProvider.notifier).setSort(value),
              itemBuilder: (context) => DiscoverySort.values
                  .map(
                    (sort) =>
                        PopupMenuItem(value: sort, child: Text(sort.label)),
                  )
                  .toList(),
              child: _DropdownPill(
                icon: Icons.sort,
                label: 'Sort: ${filters.sort.label}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => const _FilterSheet(),
          ),
          icon: const Icon(Icons.tune, size: 18),
          label: const Text('Filter'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDark,
            side: const BorderSide(color: AppColors.surfaceMuted, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// Consolidates every real filter dimension (transaction type, category,
/// radius, sort) into one sheet — the same state already driven by the
/// inline tabs/chips/dropdowns above, just easier to review and reset in
/// one place on a small screen.
class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(discoveryFiltersProvider);
    final notifier = ref.read(discoveryFiltersProvider.notifier);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filters',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Text(
              'Listing Type',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filters.transactionType == null,
                  onSelected: (_) => notifier.selectTransactionType(null),
                ),
                for (final type in TransactionType.values)
                  ChoiceChip(
                    label: Text(_tabLabel(type)),
                    selected: filters.transactionType == type,
                    onSelected: (_) => notifier.selectTransactionType(type),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Category',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filters.category == null,
                  onSelected: (selected) {
                    if (filters.category != null) {
                      notifier.toggleCategory(filters.category!);
                    }
                  },
                ),
                for (final type in ListingType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: filters.category == type,
                    onSelected: (_) => notifier.toggleCategory(type),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Radius',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [5, 10, 25, 50]
                  .map(
                    (km) => ChoiceChip(
                      label: Text('Within $km km'),
                      selected: filters.radiusKm == km,
                      onSelected: (_) => notifier.setRadiusKm(km.toDouble()),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 20),
            Text(
              'Sort',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: DiscoverySort.values
                  .map(
                    (sort) => ChoiceChip(
                      label: Text(sort.label),
                      selected: filters.sort == sort,
                      onSelected: (_) => notifier.setSort(sort),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownPill extends StatelessWidget {
  const _DropdownPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
