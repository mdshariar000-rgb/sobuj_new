import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/post.dart';
import '../../../services/api_exception.dart';
import '../../../theme/app_colors.dart';

/// Opens the "edit post" composer as a modal bottom sheet, prefilled with
/// [post]'s current body/image, with a submit callback the caller supplies
/// so it can route the PATCH through whichever provider owns this post's
/// list (a group's discussion thread, or "My Posts").
Future<void> showEditPostSheet(
  BuildContext context, {
  required Post post,
  required EditPostSubmit onSubmit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => EditPostSheet(post: post, onSubmit: onSubmit),
  );
}

typedef EditPostSubmit =
    Future<void> Function(
      WidgetRef ref,
      String body,
      File? newImage,
      bool removeImage,
    );

class EditPostSheet extends ConsumerStatefulWidget {
  const EditPostSheet({super.key, required this.post, required this.onSubmit});

  final Post post;
  final EditPostSubmit onSubmit;

  @override
  ConsumerState<EditPostSheet> createState() => _EditPostSheetState();
}

class _EditPostSheetState extends ConsumerState<EditPostSheet> {
  late final _bodyController = TextEditingController(text: widget.post.body);

  /// A newly picked replacement photo. Null means "keep whatever
  /// [_removeExistingImage] says about the post's current photo".
  File? _newImage;

  /// True once the user has explicitly removed the post's existing photo
  /// (and hasn't since picked a new one) — distinct from "never had one".
  bool _removeExistingImage = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  bool get _hasExistingImage =>
      widget.post.imageUrl != null && !_removeExistingImage;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _newImage = File(picked.path);
        _removeExistingImage = false;
      });
    }
  }

  void _removeImage() {
    setState(() {
      _newImage = null;
      _removeExistingImage = true;
    });
  }

  Future<void> _submit() async {
    if (_bodyController.text.trim().isEmpty) {
      setState(() => _errorMessage = "A post can't be empty.");
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(
        ref,
        _bodyController.text.trim(),
        _newImage,
        _removeExistingImage && _newImage == null,
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit post',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _bodyController,
            maxLines: 5,
            minLines: 3,
            decoration: const InputDecoration(
              hintText: "What's growing in your garden?",
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          if (_newImage != null)
            _ImagePreview(
              onRemove: () => setState(() => _newImage = null),
              child: Image.file(
                _newImage!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else if (_hasExistingImage)
            _ImagePreview(
              onRemove: _removeImage,
              child: CachedNetworkImage(
                imageUrl: widget.post.imageUrl!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _isSubmitting ? null : _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('Add a photo'),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(14), child: child),
        IconButton(
          icon: const CircleAvatar(
            radius: 14,
            backgroundColor: Colors.black54,
            child: Icon(Icons.close, size: 16, color: Colors.white),
          ),
          onPressed: onRemove,
        ),
      ],
    );
  }
}
