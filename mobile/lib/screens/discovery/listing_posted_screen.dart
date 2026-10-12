import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/listing.dart';
import '../../providers/discovery_providers.dart';
import '../../theme/app_colors.dart';
import 'create_listing_screen.dart';
import 'favorites_screen.dart';
import 'listing_detail_screen.dart';
import 'messages_screen.dart';
import 'widgets/marketplace_hero_header.dart';

/// "Your item has been posted!" — shown in place of the Sell/Swap form
/// once the listing is live, with shortcuts to view it or post another.
class ListingPostedScreen extends ConsumerWidget {
  const ListingPostedScreen({
    super.key,
    required this.listing,
    required this.mode,
  });

  final Listing listing;
  final ListingFormMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            onBack: () => Navigator.of(context).pop(),
            onMessagesTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
            onFavoritesTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FavoritesScreen())),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Your item has been posted!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark,
                          ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your listing is now live in the marketplace and visible to '
                      'nearby users.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, height: 1.4),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('posted-view-listing'),
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => ListingDetailScreen(listing: listing),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('View Listing'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('posted-post-another'),
                      onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => CreateListingScreen(mode: mode),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      child: const Text('Post Another Item'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
