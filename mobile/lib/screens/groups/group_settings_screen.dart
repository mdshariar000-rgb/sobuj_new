import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/group.dart';
import '../../providers/group_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import 'widgets/group_category_picker.dart';

const _nameMaxLength = 255;
const _descriptionMaxLength = 2000;

/// The group admin/creator's real settings form — name/description/
/// category/cover/avatar/privacy, all backed by the same
/// GroupController::update() endpoint create_group_screen.dart posts to.
/// Slug is deliberately not editable here even though the backend allows
/// it — it's the group's shareable identity, and silently breaking an
/// existing invite link isn't something this screen should do unasked.
/// Only reachable when [Group.myRoleIsAdmin] is true (see the app bar
/// settings icon on GroupDetailScreen).
class GroupSettingsScreen extends ConsumerStatefulWidget {
  const GroupSettingsScreen({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<GroupSettingsScreen> createState() =>
      _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends ConsumerState<GroupSettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late String? _selectedCategory;
  late bool _isPrivate;

  File? _coverImage;
  File? _avatarImage;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group.name);
    _descriptionController = TextEditingController(
      text: widget.group.description ?? '',
    );
    _selectedCategory = widget.group.category;
    _isPrivate = widget.group.isPrivate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(groupDetailProvider(widget.group).notifier)
          .updateGroup(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
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
                      child: Text(
                        'Group Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    FilledButton(
                      key: const Key('group-settings-save-button'),
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
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
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
                              : widget.group.coverImageUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(
                                    widget.group.coverImageUrl!,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child:
                            _coverImage == null &&
                                widget.group.coverImageUrl == null
                            ? const Center(
                                child: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  color: AppColors.primary,
                                ),
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
                                : widget.group.avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(
                                      widget.group.avatarUrl!,
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child:
                              _avatarImage == null &&
                                  widget.group.avatarUrl == null
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
                  key: const Key('group-settings-name-field'),
                  controller: _nameController,
                  maxLength: _nameMaxLength,
                  onChanged: (_) => setState(() {}),
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
                    key: const Key('group-settings-private-switch'),
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
                  key: const Key('group-settings-description-field'),
                  controller: _descriptionController,
                  maxLines: 4,
                  maxLength: _descriptionMaxLength,
                  onChanged: (_) => setState(() {}),
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  decoration: const InputDecoration(
                    hintText: 'A cooperative space for regenerative gardeners...',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
