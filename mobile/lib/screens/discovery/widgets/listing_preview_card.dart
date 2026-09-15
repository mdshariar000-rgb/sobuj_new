import 'package:flutter/material.dart';

import '../../../models/listing.dart';
import 'listing_thumbnail.dart';

/// The card that pops up over the map when a pin is tapped: thumbnail,
/// distance away, title, and a "Looking For" tag.
class ListingPreviewCard extends StatelessWidget {
  const ListingPreviewCard({
    required this.listing,
    this.onTap,
    this.onClose,
    super.key,
  });

  final Listing listing;
  final VoidCallback? onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lookingFor = listing.lookingFor;

    return Card(
      elevation: 6,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListingThumbnail(url: listing.thumbnailUrl, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      listing.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (listing.distanceKm != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${listing.distanceKm!.toStringAsFixed(1)} km away',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                    if (lookingFor != null && lookingFor.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Chip(
                        avatar: const Icon(Icons.swap_horiz, size: 16),
                        label: Text('Looking for: $lookingFor'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  tooltip: 'Close',
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
