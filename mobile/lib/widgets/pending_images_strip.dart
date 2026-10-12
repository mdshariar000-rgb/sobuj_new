import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'image_gallery_viewer.dart';

/// Most photos one chat message can carry — matches MAX_IMAGES on the
/// backend (HasMessageImages).
const maxChatImages = 10;

/// Lets the user pick up to [remaining] photos from the gallery at once.
/// Same size/quality limits the single-photo picker always used.
Future<List<File>> pickChatImagesFromGallery({required int remaining}) async {
  if (remaining <= 0) return const [];
  final picked = await ImagePicker().pickMultiImage(
    maxWidth: 1600,
    imageQuality: 85,
    // pickMultiImage rejects a limit below 2; the take() below still caps it.
    limit: remaining < 2 ? 2 : remaining,
  );
  return picked.take(remaining).map((file) => File(file.path)).toList();
}

/// Photos picked for the next message, shown above the composer before
/// sending — tap one to preview it full screen, or its ✕ to drop it.
class PendingImagesStrip extends StatelessWidget {
  const PendingImagesStrip({
    super.key,
    required this.files,
    required this.onRemove,
  });

  final List<File> files;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 84,
      child: ListView.separated(
        key: const Key('pending-images-strip'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        itemCount: files.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: () => openImageGallery(
                context,
                images: [for (final file in files) GalleryImage.file(file)],
                initialIndex: index,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(
                  files[index],
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Positioned(
              top: -6,
              right: -6,
              child: Material(
                color: Colors.black87,
                shape: const CircleBorder(),
                child: InkWell(
                  key: Key('remove-pending-image-$index'),
                  customBorder: const CircleBorder(),
                  onTap: () => onRemove(index),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
