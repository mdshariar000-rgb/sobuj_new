import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../providers/post_providers.dart';
import '../../../services/api_exception.dart';
import '../../../theme/app_colors.dart';

/// Opens the "new post" composer as a modal bottom sheet, posting to the
/// general Home Feed via [homeFeedProvider] on submit. Groups use their own
/// full-screen composer (CreateGroupPostScreen) instead, to match that
/// design's dedicated header/Post-button layout.
Future<void> showCreatePostSheet(BuildContext context) {
  return _showCreatePostSheet(
    context,
    onSubmit: (ref, body, category, image) => ref
        .read(homeFeedProvider.notifier)
        .createPost(body: body, category: category, image: image),
  );
}

typedef SubmitPost =
    Future<void> Function(
      WidgetRef ref,
      String body,
      String? category,
      File? image,
    );

Future<void> _showCreatePostSheet(
  BuildContext context, {
  required SubmitPost onSubmit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceContainer,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => CreatePostSheet(onSubmit: onSubmit),
  );
}

class CreatePostSheet extends ConsumerStatefulWidget {
  const CreatePostSheet({super.key, required this.onSubmit});

  final SubmitPost onSubmit;

  @override
  ConsumerState<CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<CreatePostSheet> {
  final _bodyController = TextEditingController();
  File? _image;

  /// The category name the user explicitly picked. Null means "not
  /// explicitly chosen yet" — the General chip still shows selected (see
  /// build()) and, if left that way, no category is sent at all, letting
  /// the backend apply its own real default rather than this screen
  /// hardcoding what that default is.
  String? _category;
  bool _isSubmitting = false;
  String? _errorMessage;

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
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _submit() async {
    if (_bodyController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Write something before posting.');
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
        _category,
        _image,
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
    final categoriesAsync = ref.watch(postCategoriesProvider);

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
            'New post',
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
          categoriesAsync.when(
            loading: () => const SizedBox(
              height: 32,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            // Fail open: a post can still be created without picking a
            // category if the admin-managed list can't be fetched — the
            // backend applies its own real default.
            error: (error, _) => const SizedBox.shrink(),
            data: (categories) {
              if (categories.isEmpty) return const SizedBox.shrink();
              return Wrap(
                spacing: 8,
                children: categories.map((category) {
                  final isSelected =
                      _category == category.name ||
                      (_category == null &&
                          category.name.toLowerCase() == 'general');
                  return ChoiceChip(
                    label: Text(category.name),
                    selected: isSelected,
                    onSelected: _isSubmitting
                        ? null
                        : (_) => setState(() => _category = category.name),
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textDark,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: AppColors.surfaceMuted,
                    shape: const StadiumBorder(),
                    side: BorderSide.none,
                  );
                }).toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 12),
          if (_image != null)
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    _image!,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                IconButton(
                  icon: const CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                  onPressed: () => setState(() => _image = null),
                ),
              ],
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
                : const Text('Post'),
          ),
        ],
      ),
    );
  }
}
