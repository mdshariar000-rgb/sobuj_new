import 'dart:io';

import 'package:flutter/material.dart';

import 'image_gallery_viewer.dart';
import 'image_decode.dart';

/// The photos of one chat message, laid out as a grid inside its bubble.
/// One photo shows large; several show as a two-column grid of squares, at
/// most [_maxTiles], with a "+N" overlay on the last tile for the rest.
/// Tapping any tile opens every photo full screen at that one.
class ChatImageGrid extends StatelessWidget {
  const ChatImageGrid({
    super.key,
    this.urls = const [],
    this.files = const [],
    this.width = 220,
  });

  /// Uploaded photos. Ignored while [files] is non-empty.
  final List<String> urls;

  /// Photos still only on this device — a message that's still sending.
  final List<File> files;

  final double width;

  static const _maxTiles = 4;
  static const _gap = 4.0;

  List<GalleryImage> get _images => files.isNotEmpty
      ? [for (final file in files) GalleryImage.file(file)]
      : [for (final url in urls) GalleryImage.network(url)];

  @override
  Widget build(BuildContext context) {
    final images = _images;
    if (images.isEmpty) return const SizedBox.shrink();

    if (images.length == 1) {
      return _Tile(
        key: const Key('chat-image-0'),
        image: images.first,
        width: width,
        height: width,
        onTap: () => openImageGallery(context, images: images),
      );
    }

    final shown = images.take(_maxTiles).toList();
    final hidden = images.length - shown.length;
    final tileSize = (width - _gap) / 2;

    return SizedBox(
      width: width,
      child: Wrap(
        spacing: _gap,
        runSpacing: _gap,
        children: [
          for (var i = 0; i < shown.length; i++)
            _Tile(
              key: Key('chat-image-$i'),
              image: shown[i],
              width: tileSize,
              height: tileSize,
              moreCount: i == shown.length - 1 && hidden > 0 ? hidden : 0,
              onTap: () =>
                  openImageGallery(context, images: images, initialIndex: i),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.image,
    required this.width,
    required this.height,
    required this.onTap,
    this.moreCount = 0,
  });

  final GalleryImage image;
  final double width;
  final double height;
  final VoidCallback onTap;
  final int moreCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(
                // Decoded at tile size; the full-screen viewer decodes its own.
                image: ResizeImage.resizeIfNeeded(
                  decodeWidthFor(context, width, height),
                  null,
                  image.provider,
                ),
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
              if (moreCount > 0)
                ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      '+$moreCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
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
