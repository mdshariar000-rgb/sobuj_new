import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/listing.dart';
import '../../providers/core_providers.dart';
import '../../providers/discovery_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import 'listing_detail_screen.dart';
import 'swap_offer_thread_screen.dart';
import 'discovery_screen.dart';
import '../../widgets/shimmer.dart';

/// Real "Favorites" — every listing the user has tapped the heart icon on
/// (GET /listings/saved), not a client-side-only bookmark.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  Future<void> _unsave(
    BuildContext context,
    WidgetRef ref,
    Listing listing,
  ) async {
    try {
      await ref.read(savedListingsProvider.notifier).unsave(listing);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _makeOffer(
    BuildContext context,
    WidgetRef ref,
    Listing listing,
  ) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final offer = await apiClient.createSwapOffer(listing.id);
      if (context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SwapOfferThreadScreen(swapOffer: offer),
          ),
        );
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedAsync = ref.watch(savedListingsProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Favorites')),
      body: savedAsync.when(
        loading: () => const ShimmerListingGrid(rows: 3),
        error: (error, _) => Center(child: Text('$error')),
        data: (listings) {
          if (listings.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No favorites yet — tap the heart on a listing in the '
                  'Marketplace to save it here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(savedListingsProvider.notifier).refresh(),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: ListingGrid(
                    listings: listings,
                    onTap: (listing) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ListingDetailScreen(listing: listing),
                      ),
                    ),
                    onChat: (listing) =>
                        () => _makeOffer(context, ref, listing),
                    onToggleSave: (listing) => _unsave(context, ref, listing),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
