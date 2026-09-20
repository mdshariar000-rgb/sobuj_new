import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/enums.dart';
import '../../providers/core_providers.dart';
import '../../providers/discovery_providers.dart';
import '../../providers/location_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';

/// The real screen behind the Marketplace banner's "Sell, Buy or Trade"
/// button — posts to the same StoreListingRequest endpoint this app's
/// original marketplace build already had ready, just never had a mobile
/// UI in front of it.
///
/// Sectioned to match the shared reference design (Listing Intent / Photos /
/// Category / Pricing & Exchange Terms / Trade Preference / Specimen
/// Condition / Detailed Description / Location & Handover), but every field
/// on screen maps to a real column StoreListingRequest actually accepts —
/// there's no "AI Refine" button or fixed shipping/fee options here, since
/// no such feature exists on the backend.
class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({super.key});

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _varietyController = TextEditingController();
  final _priceController = TextEditingController();
  final _lookingForController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _handoverController = TextEditingController();

  String? _listingType;
  TransactionType _transactionType = TransactionType.swap;
  ListingCondition? _condition;
  bool _openToBartering = false;
  final List<File> _photos = [];
  bool _isSubmitting = false;
  String? _errorMessage;

  static const _descriptionMaxLength = 2000;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _varietyController.dispose();
    _priceController.dispose();
    _lookingForController.dispose();
    _descriptionController.dispose();
    _handoverController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photos.length >= 6) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _photos.add(File(picked.path)));
  }

  /// The effective transaction type sent to the server — "Open to
  /// counter-offers and bartering" on a For Sale listing is just an honest
  /// UI label over the existing `swap_or_cash` value, not a new field.
  TransactionType get _effectiveTransactionType {
    if (_transactionType == TransactionType.sell && _openToBartering) {
      return TransactionType.swapOrCash;
    }
    return _transactionType;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final position = await ref.read(deviceLocationProvider.future);
      await ref
          .read(apiClientProvider)
          .createListing(
            title: _titleController.text.trim(),
            variety: _varietyController.text.trim().isEmpty
                ? null
                : _varietyController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            condition: _transactionType.isRequest ? null : _condition,
            listingType: _listingType!,
            transactionType: _effectiveTransactionType,
            price: _priceController.text.trim().isEmpty
                ? null
                : double.tryParse(_priceController.text.trim()),
            lookingFor: _lookingForController.text.trim().isEmpty
                ? null
                : _lookingForController.text.trim(),
            handoverNote: _handoverController.text.trim().isEmpty
                ? null
                : _handoverController.text.trim(),
            latitude: position.latitude,
            longitude: position.longitude,
            photos: _transactionType.isRequest ? const [] : _photos,
          );

      // The Marketplace list won't show this until it refetches — nudge it
      // now so posting feels immediate rather than needing a pull-to-refresh.
      ref.invalidate(nearbyListingsProvider);

      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// A dropdown over the real, admin-managed category list (see
  /// ListingCategoryResource/ListingCategoryController on the backend) —
  /// marketplace categories are curated from the admin panel, not typed
  /// freely here.
  Widget _buildCategoryField() {
    final categoriesAsync = ref.watch(listingCategoriesProvider);

    return categoriesAsync.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(labelText: 'Category *', enabled: false),
        child: Text(
          'Loading categories…',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
      error: (error, _) => const InputDecorator(
        decoration: InputDecoration(labelText: 'Category *', enabled: false),
        child: Text(
          'Could not load categories',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
      data: (categories) => DropdownButtonFormField<String>(
        key: const Key('create-listing-category-field'),
        initialValue: _listingType,
        decoration: const InputDecoration(labelText: 'Category *'),
        items: categories
            .map(
              (category) => DropdownMenuItem(
                value: category.name,
                child: Text(category.name),
              ),
            )
            .toList(),
        validator: (value) => value == null ? 'Select a category.' : null,
        onChanged: (value) => setState(() => _listingType = value),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRequest = _transactionType.isRequest;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: const Text('Post a Listing')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                  const SizedBox(height: 16),
                ],

                // --- Listing Intent ---
                _SectionCard(
                  icon: Icons.grass_outlined,
                  title: 'Listing Intent',
                  subtitle: 'What are you looking to do?',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: TransactionType.values.map((type) {
                      return ChoiceChip(
                        label: Text(type.label),
                        selected: _transactionType == type,
                        onSelected: (_) => setState(() {
                          _transactionType = type;
                          _openToBartering = false;
                        }),
                      );
                    }).toList(),
                  ),
                ),

                if (!isRequest) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    icon: Icons.photo_camera_outlined,
                    title: 'Photos & Specimen Proof',
                    subtitle: 'Add clear, well-lit images (up to 6).',
                    trailing: _UploadCountBadge(count: _photos.length, max: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < _photos.length; i++)
                          _PhotoThumbnail(
                            photo: _photos[i],
                            isPrimary: i == 0,
                            onRemove: () => setState(() => _photos.removeAt(i)),
                          ),
                        if (_photos.length < 6)
                          _AddPhotoTile(onTap: _pickPhoto),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.label_outline,
                  title: isRequest
                      ? 'What You\'re Looking For'
                      : 'Title & Category',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        key: const Key('create-listing-title-field'),
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: isRequest
                              ? 'What are you looking for? *'
                              : 'Listing Title *',
                          hintText: isRequest
                              ? 'e.g. Heavy Duty Broadfork'
                              : 'e.g. Meyer Lemon Rootstock',
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? 'Enter a title.'
                            : null,
                      ),
                      if (!isRequest) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _varietyController,
                          decoration: const InputDecoration(
                            labelText: 'Variety (optional)',
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _buildCategoryField(),
                    ],
                  ),
                ),

                // --- Pricing & Exchange Terms ---
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.sell_outlined,
                  title: isRequest ? 'Budget' : 'Pricing & Exchange Terms',
                  child: isRequest
                      ? TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Budget (optional)',
                            hintText: 'Max you\'d pay',
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _SegmentButton(
                                      label: 'Set Price / Value',
                                      selected:
                                          _transactionType ==
                                              TransactionType.sell ||
                                          _transactionType ==
                                              TransactionType.swapOrCash,
                                      onTap: () => setState(
                                        () => _transactionType =
                                            TransactionType.sell,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _SegmentButton(
                                      label: 'Free / Gift',
                                      selected:
                                          _transactionType ==
                                          TransactionType.free,
                                      onTap: () => setState(
                                        () => _transactionType =
                                            TransactionType.free,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: _SegmentButton(
                                      label: 'Trade Only',
                                      selected:
                                          _transactionType ==
                                          TransactionType.swap,
                                      onTap: () => setState(
                                        () => _transactionType =
                                            TransactionType.swap,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_transactionType == TransactionType.sell ||
                                _transactionType ==
                                    TransactionType.swapOrCash) ...[
                              const SizedBox(height: 14),
                              TextFormField(
                                key: const Key('create-listing-price-field'),
                                controller: _priceController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Estimated Value / Price *',
                                ),
                                validator: (value) =>
                                    (value == null || value.trim().isEmpty)
                                    ? 'Enter a price.'
                                    : null,
                              ),
                              CheckboxListTile(
                                value: _openToBartering,
                                onChanged: (value) => setState(
                                  () => _openToBartering = value ?? false,
                                ),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: const Text(
                                  'Open to counter-offers and bartering',
                                  style: TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ],
                        ),
                ),

                // --- Trade Preference ---
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.swap_horiz,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              isRequest
                                  ? 'Any Other Details'
                                  : 'Trade Preference (Willing to Accept)',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.forestDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _lookingForController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceContainer,
                          hintText: isRequest
                              ? 'Any other details buyers should know.'
                              : 'e.g. Heirloom scions, organic compost, or '
                                    'elderberry cuttings',
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isRequest
                            ? 'Optional — helps the right grower reach out.'
                            : 'Specify items to unlock matches with '
                                  'neighboring gardeners.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // --- Specimen Condition ---
                if (!isRequest) ...[
                  const SizedBox(height: 16),
                  _SectionCard(
                    icon: Icons.eco_outlined,
                    title: 'Specimen Condition',
                    subtitle: 'Select the most accurate health status.',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ListingCondition.values.map((condition) {
                        return ChoiceChip(
                          label: Text(condition.label),
                          selected: _condition == condition,
                          onSelected: (selected) => setState(
                            () => _condition = selected ? condition : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // --- Detailed Description ---
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.description_outlined,
                  title: 'Detailed Description',
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    maxLength: _descriptionMaxLength,
                    decoration: const InputDecoration(
                      hintText:
                          'Share care history, size, growing conditions — '
                          'anything a buyer or trader would want to know.',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),

                // --- Location & Handover ---
                const SizedBox(height: 16),
                _SectionCard(
                  icon: Icons.place_outlined,
                  title: 'Location & Handover',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Your current location will be used as the pickup '
                        'area (shown to others as an approximate radius).',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _handoverController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Handover notes (optional)',
                          hintText:
                              'e.g. Weekday evening pickup, or can meet '
                              'nearby',
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Meet in a public place when possible, and '
                          'inspect any plant material for pests or disease '
                          'before you accept it.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.eco, size: 18),
                  label: Text(isRequest ? 'Post Request' : 'Publish Listing'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _UploadCountBadge extends StatelessWidget {
  const _UploadCountBadge({required this.count, required this.max});

  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count / $max uploaded',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.forestDark,
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.photo,
    required this.isPrimary,
    required this.onRemove,
  });

  final File photo;
  final bool isPrimary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(photo, width: 100, height: 100, fit: BoxFit.cover),
        ),
        if (isPrimary)
          Positioned(
            left: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.forestDark,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Primary',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mint,
                ),
              ),
            ),
          ),
        Positioned(
          right: 4,
          top: 4,
          child: IconButton(
            icon: const CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.forestDark,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.buttonMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo_outlined,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add Photo',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceContainer : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.forestDark : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
