import 'package:flutter/material.dart';

import '../../../models/listing.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/user_avatar.dart';
import '../seller_profile_screen.dart';
import 'category_chips.dart';
import 'listing_price.dart';
import 'listing_thumbnail.dart';

/// One tile in the Marketplace's two-column grid: photo with a heart, the
/// title and price, who's selling it, its category, and a chat button.
class ListingGridCard extends StatelessWidget {
  const ListingGridCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onChat,
    this.onToggleSave,
  });

  final Listing listing;
  final VoidCallback? onTap;
  final VoidCallback? onChat;
  final VoidCallback? onToggleSave;

  @override
  Widget build(BuildContext context) {
    final sellerName = listing.owner?.name ?? 'Unknown grower';
    final isSaved = listing.isSaved ?? false;

    return Material(
      key: Key('listing-card-${listing.id}'),
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.35,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  listing.transactionType.isRequest && listing.photos.isEmpty
                      ? Container(
                          color: AppColors.surfaceMuted,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.shopping_cart_outlined,
                            size: 32,
                            color: AppColors.textMuted,
                          ),
                        )
                      : ListingThumbnail(
                          url: listing.thumbnailUrl,
                          size: double.infinity,
                          height: double.infinity,
                          borderRadius: 0,
                        ),
                  if (onToggleSave != null)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: _HeartButton(
                        key: Key('listing-save-${listing.id}'),
                        isSaved: isSaved,
                        onTap: onToggleSave!,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    listingPriceLabel(listing),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  openUserProfile(context, listing.owner?.id),
                              child: Row(
                                children: [
                                  UserAvatar(
                                    name: sellerName,
                                    avatarUrl: listing.owner?.avatarUrl,
                                    radius: 9,
                                    fallbackColor: AppColors.mintLight,
                                    fallbackTextColor: AppColors.primary,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      sellerName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            CategoryTag(category: listing.listingType),
                          ],
                        ),
                      ),
                      if (onChat != null) ...[
                        const SizedBox(width: 4),
                        Material(
                          color: AppColors.mintLight,
                          shape: const CircleBorder(),
                          child: InkWell(
                            key: Key('listing-chat-${listing.id}'),
                            customBorder: const CircleBorder(),
                            onTap: onChat,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(
                                Icons.chat_bubble_outline,
                                size: 18,
                                color: AppColors.forestDark,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
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

/// A small pale-mint pill with the category's icon and name.
class CategoryTag extends StatelessWidget {
  const CategoryTag({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.mintLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(categoryIcon(category), size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({super.key, required this.isSaved, required this.onTap});

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
          color: Colors.black45,
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
