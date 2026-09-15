import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/auth_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_avatar.dart';

const _maxGrowingInterests = 10;
const _maxInterestLength = 40;
const _maxBioLength = 300;

/// Real PATCH /auth/me — every field here maps to an actual UpdateProfileRequest
/// field on the backend. No phone "Verified" badge (that would need real OTP
/// verification, which doesn't exist), no email edit (no email-change flow
/// was built), and no "Zone 9b Grower" badge (that's a fabricated hardiness
/// zone feature from the reference design).
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  late final TextEditingController _interestController;

  late List<String> _growingInterests;
  late bool _showHandoverRadius;
  File? _avatarFile;
  File? _coverPhotoFile;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull;
    _nameController = TextEditingController(text: user?.name ?? '');
    _usernameController = TextEditingController(text: user?.username ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
    _locationController = TextEditingController(
      text: user?.locationLabel ?? '',
    );
    _interestController = TextEditingController();
    _growingInterests = List.of(user?.growingInterests ?? const []);
    _showHandoverRadius = user?.showHandoverRadius ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _avatarFile = File(picked.path));
  }

  Future<void> _pickCoverPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _coverPhotoFile = File(picked.path));
  }

  void _addInterest() {
    final value = _interestController.text.trim();
    if (value.isEmpty) return;
    if (_growingInterests.length >= _maxGrowingInterests) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can add up to $_maxGrowingInterests interests.'),
        ),
      );
      return;
    }
    if (value.length > _maxInterestLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Keep each interest under $_maxInterestLength characters.',
          ),
        ),
      );
      return;
    }
    if (_growingInterests.contains(value)) {
      _interestController.clear();
      return;
    }
    setState(() {
      _growingInterests.add(value);
      _interestController.clear();
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .updateProfile(
            name: _nameController.text.trim(),
            username: _usernameController.text.trim().isEmpty
                ? null
                : _usernameController.text.trim(),
            bio: _bioController.text.trim(),
            phone: _phoneController.text.trim(),
            locationLabel: _locationController.text.trim(),
            growingInterests: _growingInterests,
            showHandoverRadius: _showHandoverRadius,
            avatar: _avatarFile,
            coverPhoto: _coverPhotoFile,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  static InputDecoration _fieldDecoration({
    String? label,
    String? hint,
    String? helper,
    String? prefixText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixText: prefixText,
      filled: true,
      fillColor: AppColors.surfaceMuted,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: const Text('Save Changes'),
          ),
        ],
      ),
      body: user == null
          ? const SizedBox.shrink()
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: _pickCoverPhoto,
                          child: Container(
                            height: 144,
                            width: double.infinity,
                            color: AppColors.forestPanel,
                            child: _coverPhotoFile != null
                                ? Image.file(
                                    _coverPhotoFile!,
                                    fit: BoxFit.cover,
                                  )
                                : (user.coverPhotoUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: user.coverPhotoUrl!,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, _, _) =>
                                              const SizedBox.shrink(),
                                        )
                                      : null),
                          ),
                        ),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: _EditCoverBadge(onTap: _pickCoverPhoto),
                        ),
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: GestureDetector(
                            onTap: _pickAvatar,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: _avatarFile != null
                                      ? CircleAvatar(
                                          radius: 44,
                                          backgroundImage: FileImage(
                                            _avatarFile!,
                                          ),
                                        )
                                      : UserAvatar(
                                          name: user.name,
                                          avatarUrl: user.avatarUrl,
                                          radius: 44,
                                        ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FormSectionCard(
                    children: [
                      TextFormField(
                        key: const Key('edit-profile-name-field'),
                        controller: _nameController,
                        decoration: _fieldDecoration(label: 'Full Name'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Name is required'
                            : null,
                      ),
                      TextFormField(
                        key: const Key('edit-profile-username-field'),
                        controller: _usernameController,
                        decoration: _fieldDecoration(
                          label: 'Username / Handle',
                          prefixText: '@',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final valid = RegExp(
                            r'^[a-zA-Z0-9_]+$',
                          ).hasMatch(value.trim());
                          return valid ? null : 'Letters, numbers, _ only';
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FormSectionCard(
                    children: [
                      TextFormField(
                        key: const Key('edit-profile-phone-field'),
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: _fieldDecoration(label: 'Phone Number'),
                      ),
                      TextFormField(
                        key: const Key('edit-profile-email-field'),
                        initialValue: user.email ?? '',
                        readOnly: true,
                        decoration: _fieldDecoration(
                          label: 'Email Address',
                          helper: 'Email cannot be changed here.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FormSectionCard(
                    children: [
                      TextFormField(
                        key: const Key('edit-profile-bio-field'),
                        controller: _bioController,
                        maxLength: _maxBioLength,
                        maxLines: 3,
                        decoration: _fieldDecoration(
                          label: 'Bio / About',
                        ).copyWith(alignLabelWithHint: true),
                        onChanged: (_) => setState(() {}),
                      ),
                      TextFormField(
                        key: const Key('edit-profile-location-field'),
                        controller: _locationController,
                        decoration: _fieldDecoration(
                          label: 'Primary Location',
                          hint: 'e.g. Napa Valley, CA',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FormSectionCard(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Growing Interests & Focus',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final interest in _growingInterests)
                            _InterestChip(
                              label: interest,
                              onDeleted: () => setState(
                                () => _growingInterests.remove(interest),
                              ),
                            ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('edit-profile-interest-field'),
                              controller: _interestController,
                              decoration: _fieldDecoration(
                                hint: 'Add an interest (e.g. Tomatoes)',
                              ),
                              onSubmitted: (_) => _addInterest(),
                            ),
                          ),
                          IconButton(
                            key: const Key(
                              'edit-profile-add-interest-button',
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                            color: AppColors.primary,
                            onPressed: _addInterest,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FormSectionCard(
                    children: [
                      SwitchListTile(
                        key: const Key('edit-profile-handover-switch'),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Community Handover Radius'),
                        subtitle: const Text(
                          'Show your approximate location to other growers '
                          'on your listings and profile.',
                        ),
                        value: _showHandoverRadius,
                        onChanged: (value) =>
                            setState(() => _showHandoverRadius = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: const Text('Save Changes'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your location is never shown exactly — only a '
                    'fuzzed approximation, and only when Community '
                    'Handover Radius is on.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }
}

/// A bordered white card grouping related fields — matches the reference
/// design's "Bento card" sections (Name/Username, Contact, Bio/Location,
/// Growing Interests, Privacy).
class _FormSectionCard extends StatelessWidget {
  const _FormSectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _EditCoverBadge extends StatelessWidget {
  const _EditCoverBadge({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.forestPanel,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, size: 13, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Change Cover Photo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A real, freeform interest chip — styled to match the reference's "active"
/// tag chips (dark-green fill, white text, remove icon). There is no global
/// suggested-tags catalog to also render the reference's "inactive/available"
/// chip variant — see the class doc comment on [EditProfileScreen].
class _InterestChip extends StatelessWidget {
  const _InterestChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.forestPanel,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: onDeleted,
            child: const Icon(Icons.close, size: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
