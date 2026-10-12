import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../widgets/image_decode.dart';

/// Shared thumbnail rendering for both the list card and the map preview
/// card — a placeholder icon when a listing has no photos, rather than an
/// empty gap.
class ListingThumbnail extends StatelessWidget {
  const ListingThumbnail({
    required this.url,
    this.size = 64,
    double? height,
    this.borderRadius = 8,
    super.key,
  }) : height = height ?? size;

  final String? url;
  final double size;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    if (url == null) {
      return ClipRRect(
        borderRadius: radius,
        child: Container(
          width: size,
          height: height,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.eco_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: height,
        memCacheWidth: decodeWidthFor(context, size, height),
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          width: size,
          height: height,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (context, _, _) => Container(
          width: size,
          height: height,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image_outlined),
        ),
      ),
    );
  }
}
