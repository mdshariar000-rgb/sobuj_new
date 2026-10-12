import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/group_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import 'widgets/group_category_picker.dart';

const _nameMaxLength = 255;
const _descriptionMaxLength = 2000;

/// Lowercases, replaces runs of non-alphanumeric characters with a single
/// hyphen, and trims leading/trailing hyphens — a reasonable slug for the
/// backend's `alpha_dash` + unique validation without round-tripping to
/// the server just to preview it.
String _slugify(String input) {
  final lower = input.trim().toLowerCase();
  final hyphenated = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return hyphenated.replaceAll(RegExp(r'^-+|-+$'), '');
}

/// A full-screen "Create a Group" form, matching the reference design's
/// real, buildable fields only. Includes the real Public/Private toggle —
/// a private group requires the admin's approval to join and, for non-admin
/// members, to post (see GroupController::join()/PostController::store()
/// on the backend). Still deliberately omits: "Enable Group Chat Messenger"
/// toggle (chat is always available — not a real per-group setting),
/// Region/USDA Hardiness Zone (no such field), Community Rules/manifesto
/// section (Group has no rules field), and "Save Draft" (no draft-saving
/// feature exists).
class CreateGroupScreen extends ConsumerStatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  ConsumerState<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends ConsumerState<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedCategory;
  bool _isPrivate = false;

  File? _coverImage;
  File? _avatarImage;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _slugManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
    _descriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    if (!_slugManuallyEdited) {
      _slugController.text = _slugify(value);
    }
  }

  Future<void> _pickCoverImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _coverImage = File(picked.path));
  }

  Future<void> _pickAvatarImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _avatarImage = File(picked.path));
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(groupsListProvider.notifier)
          .createGroup(
            name: _nameController.text.trim(),
            slug: _slugController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            category: _selectedCategory,
            isPrivate: _isPrivate,
            coverImage: _coverImage,
            avatar: _avatarImage,
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
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.forestPanel,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AGRONOMY HUB',
                            style: TextStyle(
                              color: AppColors.mint,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          Text(
                            'Create a Group',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(minimumSize: Size.zero),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _isSubmitting ? null : _pickCoverImage,
                        child: Container(
                          height: 140,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                            image: _coverImage != null
                                ? DecorationImage(
                                    image: FileImage(_coverImage!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _coverImage == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Add Cover Photo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Recommended 1200 × 400px',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: -30,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isSubmitting ? null : _pickAvatarImage,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.mintButton,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.surface,
                                width: 4,
                              ),
                              image: _avatarImage != null
                                  ? DecorationImage(
                                      image: FileImage(_avatarImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _avatarImage == null
                                ? const Icon(
                                    Icons.eco,
                                    color: AppColors.mintButtonText,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 44),
                  const SizedBox(height: 8),
                  Text(
                    'Group Emblem',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Optional — tap to add a small logo or badge',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Group Name *',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${_nameController.text.length} / $_nameMaxLength',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    key: const Key('create-group-name-field'),
                    controller: _nameController,
                    onChanged: _onNameChanged,
                    maxLength: _nameMaxLength,
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                    decoration: const InputDecoration(
                      hintText: 'Heirloom Tomato & Permaculture Guild',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Enter a group name.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'URL Slug *',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    key: const Key('create-group-slug-field'),
                    controller: _slugController,
                    onChanged: (_) => _slugManuallyEdited = true,
                    decoration: const InputDecoration(
                      helperText: 'Letters, numbers, and hyphens only.',
                    ),
                    validator: (value) =>
                        (value == null || value.trim().isEmpty)
                        ? 'Enter a slug.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Agricultural Focus',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  GroupCategoryPicker(
                    value: _selectedCategory,
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      key: const Key('create-group-private-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Private group',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: const Text(
                        'New members need your approval to join, and '
                        'members\' posts need your approval before the '
                        'group sees them.',
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _isPrivate,
                      onChanged: _isSubmitting
                          ? null
                          : (value) => setState(() => _isPrivate = value),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Description & Purpose',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        '${_descriptionController.text.length} / $_descriptionMaxLength',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    maxLength: _descriptionMaxLength,
                    buildCounter:
                        (
                          context, {
                          required currentLength,
                          required isFocused,
                          maxLength,
                        }) => null,
                    decoration: const InputDecoration(
                      hintText:
                          'A cooperative space for regenerative gardeners...',
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'By creating a group, you agree to keep discussion '
                    'organic, on-topic, and respectful of fellow growers.',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
