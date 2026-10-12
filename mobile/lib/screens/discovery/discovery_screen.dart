import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
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
import 'widgets/discovery_error_view.dart';
import 'widgets/discovery_search_bar.dart';
import 'widgets/listing_grid_card.dart';
import 'widgets/listing_map_view.dart';
import 'widgets/marketplace_hero_header.dart';
import '../../widgets/shimmer.dart';

/// The Marketplace tab: Sell / Buy / Swap actions, search, location and
/// filters, then a two-column grid of nearby listings.
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

  /// Creates (or reopens, if one's already open) the conversation about
  /// this listing and drops straight into it — like tapping a contact
  /// opens a chat, rather than filling out a form first.
  Future<void> _messageSeller(Listing listing) async {
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

  void _openForm(ListingFormMode mode) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => CreateListingScreen(mode: mode)));
  }

  @override
  Widget build(BuildContext context) {
    final listingsAsync = ref.watch(nearbyListingsProvider);
    final viewMode = ref.watch(viewModeProvider);
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;
    final openOfferCount =
        ref
            .watch(mySwapOffersProvider)
            .valueOrNull
            ?.where((offer) => offer.status.isOpen)
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          MarketplaceHeroHeader(
            openOfferCount: openOfferCount,
            onLogoTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
            onMessagesTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
            onFavoritesTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FavoritesScreen())),
          ),
          Expanded(
            child: switch (viewMode) {
              DiscoveryViewMode.map => const ListingMapView(),
              DiscoveryViewMode.list => RefreshIndicator(
                onRefresh: () =>
                    ref.read(nearbyListingsProvider.notifier).refresh(),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _ActionTiles(
                        onSell: () => _openForm(ListingFormMode.sell),
                        onSwap: () => _openForm(ListingFormMode.swap),
                      ),
                    ),
                    const SliverToBoxAdapter(child: DiscoverySearchBar()),
                    const SliverToBoxAdapter(child: _LocationAndFilterRow()),
                    const SliverToBoxAdapter(child: _ListingsHeading()),
                    ...listingsAsync.when(
                      loading: () => const [
                        SliverToBoxAdapter(child: ShimmerListingGrid(rows: 3)),
                      ],
                      error: (error, _) => [
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: DiscoveryErrorView(
                            error: error,
                            onRetry: () => ref
                                .read(nearbyListingsProvider.notifier)
                                .refresh(),
                          ),
                        ),
                      ],
                      data: (listings) => [
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
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            sliver: ListingGrid(
                              listings: listings,
                              onTap: (listing) => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ListingDetailScreen(listing: listing),
                                ),
                              ),
                              // No chat button on your own listings — there's
                              // nobody to message.
                              onChat: (listing) =>
                                  currentUserId != null &&
                                      listing.owner?.id == currentUserId
                                  ? null
                                  : () => _messageSeller(listing),
                              onToggleSave: _toggleSave,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

/// A two-column sliver grid of [ListingGridCard]s. Each row's height is
/// worked out from the column width so the photo keeps its shape on every
/// screen size, plus room for the text below it.
class ListingGrid extends StatelessWidget {
  const ListingGrid({
    super.key,
    required this.listings,
    required this.onTap,
    required this.onChat,
    required this.onToggleSave,
  });

  final List<Listing> listings;
  final void Function(Listing listing) onTap;
  final VoidCallback? Function(Listing listing) onChat;

  /// Null hides the heart (e.g. search results, which can't update it).
  final void Function(Listing listing)? onToggleSave;

  static const _spacing = 12.0;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = (constraints.crossAxisExtent - _spacing) / 2;
        final tileHeight =
            tileWidth / 1.35 + 112 * math.max(1.0, textScale) + 4;
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            mainAxisExtent: tileHeight,
          ),
          itemCount: listings.length,
          itemBuilder: (context, index) {
            final listing = listings[index];
            return ListingGridCard(
              listing: listing,
              onTap: () => onTap(listing),
              onChat: onChat(listing),
              onToggleSave: onToggleSave == null
                  ? null
                  : () => onToggleSave!(listing),
            );
          },
        );
      },
    );
  }
}

/// Sell / Buy / Swap. Sell and Swap open the matching posting form; Buy
/// narrows the grid to items for sale (tap again to show everything).
class _ActionTiles extends ConsumerWidget {
  const _ActionTiles({required this.onSell, required this.onSwap});

  final VoidCallback onSell;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buying = ref.watch(
      discoveryFiltersProvider.select(
        (filters) => filters.transactionType == TransactionType.sell,
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: _ActionTile(
              key: const Key('marketplace-sell'),
              icon: Icons.sell_outlined,
              label: 'Sell',
              onTap: onSell,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              key: const Key('marketplace-buy'),
              icon: Icons.shopping_cart_outlined,
              label: 'Buy',
              selected: buying,
              onTap: () => ref
                  .read(discoveryFiltersProvider.notifier)
                  .selectTransactionType(buying ? null : TransactionType.sell),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              key: const Key('marketplace-swap'),
              icon: Icons.sync,
              label: 'Swap',
              onTap: onSwap,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : AppColors.forestDark;
    return Material(
      color: selected ? AppColors.primary : AppColors.mintLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Near (place) / Within 25 km ▾" (tap to change the radius) beside the
/// Filter button.
class _LocationAndFilterRow extends ConsumerWidget {
  const _LocationAndFilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final radiusKm = ref.watch(
      discoveryFiltersProvider.select((filters) => filters.radiusKm),
    );
    // Listings are searched around the location chosen at registration
    // (accountLocationProvider) — say so, since there's no GPS involved.
    final locationLabel = ref
        .watch(authControllerProvider)
        .valueOrNull
        ?.locationLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: PopupMenuButton<double>(
              key: const Key('discovery-radius-menu'),
              initialValue: radiusKm,
              onSelected: (value) => ref
                  .read(discoveryFiltersProvider.notifier)
                  .setRadiusKm(value),
              itemBuilder: (context) => _radiusOptions
                  .map(
                    (km) => PopupMenuItem(
                      value: km.toDouble(),
                      child: Text('Within $km km'),
                    ),
                  )
                  .toList(),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 20,
                      color: AppColors.forestDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        key: const Key('discovery-location-label'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationLabel != null && locationLabel.isNotEmpty
                                ? 'Near $locationLabel'
                                : 'Near you',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                          Text(
                            'Within ${radiusKm.round()} km',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.textDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            key: const Key('discovery-filter-button'),
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
              // The app theme makes buttons full-width; this one sits in a row.
              minimumSize: const Size(0, 48),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              side: const BorderSide(color: AppColors.border),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

const _radiusOptions = [5, 10, 25, 50];

/// "Listings near you" with the sort menu on the right.
class _ListingsHeading extends ConsumerWidget {
  const _ListingsHeading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sort = ref.watch(
      discoveryFiltersProvider.select((filters) => filters.sort),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Listings near you',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
          PopupMenuButton<DiscoverySort>(
            initialValue: sort,
            onSelected: (value) =>
                ref.read(discoveryFiltersProvider.notifier).setSort(value),
            itemBuilder: (context) => DiscoverySort.values
                .map(
                  (option) =>
                      PopupMenuItem(value: option, child: Text(option.label)),
                )
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'Sort: ${sort.label}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The listing types the Filters sheet offers. Free and Swap-or-Cash still
/// exist on older listings, but nothing new is posted with them.
const _filterTypes = [
  (TransactionType.sell, 'For Sale (Sell)', Icons.sell_outlined),
  (TransactionType.swap, 'Swap', Icons.sync),
  (
    TransactionType.wanted,
    'Looking to Buy (Buy)',
    Icons.shopping_cart_outlined,
  ),
];

/// Listing type, category and radius in one sheet. Edits a draft copy of
/// the filters; nothing changes until "Apply Filters".
class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet();

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late DiscoveryFilters _draft = ref.read(discoveryFiltersProvider);

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(listingCategoriesProvider).valueOrNull ?? [];

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.forestDark,
        ),
      ),
    );

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Filters',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.forestDark,
                          ),
                    ),
                    heading('Listing Type'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChoice(
                          label: 'All',
                          selected: _draft.transactionType == null,
                          onTap: () => setState(
                            () => _draft = _draft.copyWith(
                              clearTransactionType: true,
                            ),
                          ),
                        ),
                        for (final (type, label, icon) in _filterTypes)
                          _FilterChoice(
                            label: label,
                            icon: icon,
                            selected: _draft.transactionType == type,
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(
                                transactionType: type,
                              ),
                            ),
                          ),
                      ],
                    ),
                    heading('Category'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChoice(
                          label: 'All',
                          selected: _draft.category == null,
                          onTap: () => setState(
                            () => _draft = _draft.copyWith(clearCategory: true),
                          ),
                        ),
                        for (final category in categories)
                          _FilterChoice(
                            label: category.name,
                            icon: categoryIcon(category.name),
                            selected: _draft.category == category.name,
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(
                                category: category.name,
                              ),
                            ),
                          ),
                      ],
                    ),
                    heading('Radius'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final km in _radiusOptions)
                          _FilterChoice(
                            label: 'Within $km km',
                            icon: Icons.place_outlined,
                            selected: _draft.radiusKm == km,
                            onTap: () => setState(
                              () => _draft = _draft.copyWith(
                                radiusKm: km.toDouble(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      key: const Key('filter-clear-all'),
                      onPressed: () => setState(
                        () => _draft = _draft.copyWith(
                          clearTransactionType: true,
                          clearCategory: true,
                          radiusKm: AppConfig.defaultRadiusKm,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.buttonMuted,
                        foregroundColor: AppColors.textDark,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Clear All'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      key: const Key('filter-apply'),
                      onPressed: () {
                        ref
                            .read(discoveryFiltersProvider.notifier)
                            .apply(_draft);
                        Navigator.of(context).pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.forestPanel,
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: const Text('Apply Filters'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.mint : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? AppColors.mint : AppColors.forestDark,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 18, color: AppColors.forestDark),
                const SizedBox(width: 6),
              ],
              if (icon != null) ...[
                Icon(icon, size: 18, color: AppColors.forestDark),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
