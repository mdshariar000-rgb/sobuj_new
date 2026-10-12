import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../models/enums.dart';
import '../../../models/listing.dart';
import '../../../providers/feed_marketplace_providers.dart';
import '../../../providers/shell_providers.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/user_avatar.dart';
import '../../discovery/listing_detail_screen.dart';
import '../../discovery/seller_profile_screen.dart';
import '../../discovery/widgets/listing_thumbnail.dart';

/// The Marketplace tab in the bottom navigation.
const _marketplaceTabIndex = 3;

/// "£3.00", "Free", "Swap", "Up to £10.00" — same wording as the
/// Marketplace tab's own listing cards.
String feedListingPriceLabel(Listing listing) {
  final price = listing.price;
  if (price != null) {
    final formatted = NumberFormat.simpleCurrency(name: 'GBP').format(price);
    return listing.transactionType.isRequest ? 'Up to $formatted' : formatted;
  }
  return listing.transactionType == TransactionType.free
      ? 'Free'
      : listing.transactionType.label;
}

String? _distanceLabel(Listing listing) => listing.distanceKm == null
    ? null
    : '${listing.distanceKm!.toStringAsFixed(1)} km away';

void _openListing(BuildContext context, Listing listing) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ListingDetailScreen(listing: listing)),
  );
}

Future<void> _toggleSaved(
  BuildContext context,
  WidgetRef ref,
  Listing listing,
) async {
  try {
    await ref.read(feedMarketplaceProvider.notifier).toggleSaved(listing);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't update saved listings.")),
      );
    }
  }
}

/// "Fresh near you": a row of marketplace listings near the user's
/// registration location, shown between posts on Home.
class NearbyListingsCarousel extends ConsumerWidget {
  const NearbyListingsCarousel({
    super.key,
    required this.listings,
    this.locationLabel,
  });

  final List<Listing> listings;
  final String? locationLabel;

  void _hide(BuildContext context, WidgetRef ref) {
    // Read up front: hiding removes this carousel, so by the time Undo is
    // tapped its `ref` is gone.
    final hidden = ref.read(nearbyCarouselHiddenProvider.notifier);
    hidden.state = true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Marketplace picks hidden for now'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => hidden.state = false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      key: const Key('nearby-listings-carousel'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.storefront_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fresh near you',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          locationLabel == null
                              ? 'From the Shobuj marketplace'
                              : 'Marketplace · near $locationLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: const Key('nearby-listings-see-all'),
                    onPressed: () =>
                        ref.read(selectedTabIndexProvider.notifier).state =
                            _marketplaceTabIndex,
                    style: TextButton.styleFrom(minimumSize: Size.zero),
                    child: const Text('See all'),
                  ),
                  PopupMenuButton<void>(
                    key: const Key('nearby-listings-menu'),
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: 'Marketplace picks options',
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        key: const Key('nearby-listings-hide'),
                        onTap: () => _hide(context, ref),
                        child: const ListTile(
                          leading: Icon(Icons.visibility_off_outlined),
                          title: Text('Hide for now'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              // 120 for the photo and gap, plus the text block — scaled so
              // the price and distance aren't clipped with Larger Text on.
              height: 120 + MediaQuery.textScalerOf(context).scale(94),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: listings.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    FeedListingTile(listing: listings[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One marketplace listing as a photo tile — the "Fresh near you" carousel
/// uses the default width; the Home grid passes its column width.
class FeedListingTile extends ConsumerWidget {
  const FeedListingTile({super.key, required this.listing, this.width = 148});

  final Listing listing;
  final double width;

  Future<void> _showOptions(BuildContext context, WidgetRef ref) async {
    final notInterested = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: ListTile(
          key: const Key('listing-not-interested'),
          leading: const Icon(Icons.not_interested),
          title: const Text('Not interested'),
          subtitle: Text(listing.title),
          onTap: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (notInterested == true) {
      ref.read(feedMarketplaceProvider.notifier).dismissNearby(listing);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isSaved = listing.isSaved ?? false;
    final distance = _distanceLabel(listing);

    return SizedBox(
      width: width,
      child: InkWell(
        key: Key('nearby-listing-${listing.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openListing(context, listing),
        onLongPress: () => _showOptions(context, ref),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ListingThumbnail(
                  url: listing.thumbnailUrl,
                  size: width,
                  height: 112,
                  borderRadius: 12,
                ),
                Positioned(
                  left: 6,
                  top: 6,
                  child: _TypePill(type: listing.transactionType),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: _SaveButton(
                    key: Key('nearby-listing-save-${listing.id}'),
                    isSaved: isSaved,
                    onTap: () => _toggleSaved(context, ref, listing),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              listing.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              feedListingPriceLabel(listing),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            if (distance != null)
              Text(
                distance,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "`name` listed a new item": a new listing from a grower the user
/// follows, placed in the feed by when it was listed.
class FollowedListingCard extends ConsumerWidget {
  const FollowedListingCard({super.key, required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final owner = listing.owner;
    final ownerName = owner?.name ?? 'A grower you follow';
    final isSaved = listing.isSaved ?? false;
    final distance = _distanceLabel(listing);

    return Card(
      key: Key('followed-listing-${listing.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openListing(context, listing),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => openUserProfile(context, owner?.id),
                    child: UserAvatar(
                      name: ownerName,
                      avatarUrl: owner?.avatarUrl,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'listed a new item · '
                          '${timeago.format(listing.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.storefront_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.textMuted.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    ListingThumbnail(
                      url: listing.thumbnailUrl,
                      size: 84,
                      borderRadius: 10,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _TypePill(type: listing.transactionType),
                          const SizedBox(height: 6),
                          Text(
                            listing.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              feedListingPriceLabel(listing),
                              ?distance,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton.icon(
                    key: Key('followed-listing-save-${listing.id}'),
                    onPressed: () => _toggleSaved(context, ref, listing),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      foregroundColor: isSaved
                          ? Colors.redAccent
                          : AppColors.textMuted,
                    ),
                    icon: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                    ),
                    label: Text(isSaved ? 'Saved' : 'Save'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _openListing(context, listing),
                    style: TextButton.styleFrom(minimumSize: Size.zero),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('View listing'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});

  final TransactionType type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      TransactionType.free => AppColors.mint,
      TransactionType.wanted => AppColors.error,
      _ => AppColors.forestDark,
    };
    final dark = type != TransactionType.free;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.isRequest ? 'Wanted Item' : type.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white : AppColors.textDark,
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({super.key, required this.isSaved, required this.onTap});

  final bool isSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSaved ? Icons.favorite : Icons.favorite_border,
          size: 17,
          color: isSaved ? Colors.redAccent : Colors.white,
        ),
      ),
    );
  }
}
