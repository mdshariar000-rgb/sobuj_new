import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/enums.dart';
import '../../../models/listing.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/user_avatar.dart';
import '../seller_profile_screen.dart';
import 'listing_thumbnail.dart';

String _ctaLabel(TransactionType type) {
  switch (type) {
    case TransactionType.sell:
    case TransactionType.swapOrCash:
      return 'Contact';
    case TransactionType.free:
      return 'Request';
    case TransactionType.swap:
      return 'Propose Trade';
    case TransactionType.wanted:
      return 'I Have This';
  }
}

/// Sell/Wanted are filled (you're paying or being paid); Free/Trade are
/// outlined — a lighter-weight action since no money changes hands.
bool _ctaFilled(TransactionType type) {
  switch (type) {
    case TransactionType.sell:
    case TransactionType.swapOrCash:
    case TransactionType.wanted:
      return true;
    case TransactionType.free:
    case TransactionType.swap:
      return false;
  }
}

Color _pillColor(TransactionType type) {
  switch (type) {
    case TransactionType.free:
      return AppColors.mint;
    case TransactionType.wanted:
      return AppColors.error;
    case TransactionType.sell:
    case TransactionType.swapOrCash:
    case TransactionType.swap:
      return AppColors.forestDark;
  }
}

/// A small, fixed palette of avatar background tints so seller initials
/// aren't all the same flat color — picked deterministically from the
/// user's real id, not random, so it stays stable across rebuilds.
const _avatarPalette = [
  Color(0xFFFDE3CF),
  Color(0xFFD6EAF8),
  Color(0xFFE3D6F8),
  Color(0xFFD6F8E3),
  Color(0xFFF8D6E0),
  Color(0xFFFFF3C4),
];

Color _avatarColor(int? userId) {
  if (userId == null) return AppColors.surfaceMuted;
  return _avatarPalette[userId % _avatarPalette.length];
}

class ListingCard extends StatelessWidget {
  const ListingCard({
    required this.listing,
    this.onTap,
    this.onCta,
    this.onToggleSave,
    super.key,
  });

  final Listing listing;
  final VoidCallback? onTap;
  final VoidCallback? onCta;
  final VoidCallback? onToggleSave;

  /// A truthful stand-in for a seller badge: derived from their real growing
  /// setup / experience level rather than an invented title like
  /// "Agronomist" — null when neither is set on their profile.
  String? get _sellerRoleLabel {
    final setup = listing.owner?.growingSetup?.label;
    if (setup != null) return '$setup Grower';
    final level = listing.owner?.experienceLevel?.label;
    if (level != null) return '$level Grower';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRequest = listing.transactionType.isRequest;
    final sellerName = listing.owner?.name ?? 'Unknown grower';
    final roleLabel = _sellerRoleLabel;
    final isVerified = listing.owner?.isVerified ?? false;
    final isSaved = listing.isSaved ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (isRequest)
                  Container(
                    width: double.infinity,
                    height: 90,
                    color: AppColors.surfaceMuted,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.handyman_outlined,
                      size: 32,
                      color: AppColors.textMuted,
                    ),
                  )
                else
                  ListingThumbnail(
                    url: listing.thumbnailUrl,
                    size: double.infinity,
                    height: 150,
                    borderRadius: 0,
                  ),
                Positioned(
                  left: 10,
                  top: 10,
                  child: _Pill(
                    label: isRequest
                        ? 'Wanted Item'
                        : listing.transactionType.label,
                    color: _pillColor(listing.transactionType),
                    dark: listing.transactionType != TransactionType.free,
                  ),
                ),
                if (onToggleSave != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _SaveButton(isSaved: isSaved, onTap: onToggleSave!),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        listing.price != null
                            ? (isRequest
                                  ? 'Up to ${NumberFormat.simpleCurrency().format(listing.price)}'
                                  : NumberFormat.simpleCurrency().format(
                                      listing.price,
                                    ))
                            : (listing.transactionType == TransactionType.free
                                  ? 'Free'
                                  : listing.transactionType.label),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      if (listing.variety != null) ...[
                        const Spacer(),
                        Flexible(
                          child: Text(
                            listing.variety!,
                            textAlign: TextAlign.end,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (listing.lookingFor != null &&
                      listing.lookingFor!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      isRequest
                          ? listing.lookingFor!
                          : 'Looking for: ${listing.lookingFor}',
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (listing.distanceKm != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${listing.distanceKm!.toStringAsFixed(1)} km away',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            openUserProfile(context, listing.owner?.id),
                        child: UserAvatar(
                          name: sellerName,
                          avatarUrl: listing.owner?.avatarUrl,
                          radius: 14,
                          fallbackColor: _avatarColor(listing.owner?.id),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              openUserProfile(context, listing.owner?.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      sellerName,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isVerified) ...[
                                    const SizedBox(width: 3),
                                    const Icon(
                                      Icons.verified,
                                      size: 13,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                              if (roleLabel != null)
                                Text(
                                  roleLabel,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      if (onCta != null)
                        _ctaFilled(listing.transactionType)
                            ? FilledButton(
                                onPressed: onCta,
                                style: FilledButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(_ctaLabel(listing.transactionType)),
                              )
                            : OutlinedButton(
                                onPressed: onCta,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: Text(_ctaLabel(listing.transactionType)),
                              ),
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

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, required this.dark});

  final String label;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
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
  const _SaveButton({required this.isSaved, required this.onTap});

  final bool isSaved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSaved ? Icons.favorite : Icons.favorite_border,
          size: 18,
          color: isSaved ? Colors.redAccent : Colors.white,
        ),
      ),
    );
  }
}
