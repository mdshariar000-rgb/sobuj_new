import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// One photo in [ImageGalleryViewer] — either already uploaded ([url]) or
/// still only on this device ([file], e.g. a message that's still sending).
class GalleryImage {
  const GalleryImage.network(String this.url) : file = null;
  const GalleryImage.file(File this.file) : url = null;

  final String? url;
  final File? file;

  /// Disk-cached for network photos, so reopening a chat doesn't
  /// re-download every image in it.
  ImageProvider get provider =>
      file != null ? FileImage(file!) : CachedNetworkImageProvider(url!);
}

/// Opens [images] full screen, starting at [initialIndex] — swipe between
/// them, pinch or double-tap to zoom.
Future<void> openImageGallery(
  BuildContext context, {
  required List<GalleryImage> images,
  int initialIndex = 0,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          ImageGalleryViewer(images: images, initialIndex: initialIndex),
    ),
  );
}

class ImageGalleryViewer extends StatefulWidget {
  const ImageGalleryViewer({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<GalleryImage> images;
  final int initialIndex;

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer> {
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: count > 1
            ? Text(
                '${_index + 1} / $count',
                key: const Key('gallery-counter'),
                style: const TextStyle(fontSize: 16),
              )
            : null,
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: count,
        onPageChanged: (index) => setState(() => _index = index),
        itemBuilder: (context, index) =>
            _ZoomableImage(image: widget.images[index]),
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.image});

  final GalleryImage image;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _transform = TransformationController();
  TapDownDetails? _lastDoubleTap;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom(TapDownDetails details) {
    if (_transform.value.getMaxScaleOnAxis() > 1) {
      _transform.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    final position = details.localPosition;
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
        0,
        1,
      )
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _lastDoubleTap = details,
      onDoubleTap: () {
        final tap = _lastDoubleTap;
        if (tap != null) _toggleZoom(tap);
      },
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image(
            image: widget.image.provider,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (context, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
