import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/enums.dart';
import '../../models/listing.dart';
import '../../models/listing_photo.dart';
import '../../providers/core_providers.dart';
import '../../providers/discovery_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import 'favorites_screen.dart';
import 'listing_posted_screen.dart';
import 'messages_screen.dart';
import 'widgets/category_chips.dart';
import 'widgets/marketplace_hero_header.dart';

/// Which marketplace form to show: "Sell an Item" (price, quantity,
/// contact) or "Swap an Item" (what you'd like in exchange).
enum ListingFormMode { sell, swap }

/// The Sell / Swap posting form behind the Marketplace's Sell and Swap
/// buttons. Posts to StoreListingRequest; the listing is placed at the
/// account's registered location (ListingController::resolveLocation).
///
/// With [editing] set it's the seller's "Edit item" form instead: filled in
/// from that listing, and saving sends only the changes (UpdateListingRequest)
/// and pops back with the updated listing.
class CreateListingScreen extends ConsumerStatefulWidget {
  const CreateListingScreen({
    super.key,
    this.mode = ListingFormMode.sell,
    this.editing,
  });

  final ListingFormMode mode;
  final Listing? editing;

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _contactController = TextEditingController();
  final _swapForController = TextEditingController();

  String? _category;

  /// Photos already on the listing (when editing) followed by new picks.
  final List<_FormPhoto> _photos = [];
  final List<int> _removedPhotoIds = [];
  bool _photosMissing = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  static const maxPhotos = 5;
  static const descriptionMaxLength = 500;

  bool get _isEditing => widget.editing != null;

  bool get _isSell => _isEditing
      ? widget.editing!.transactionType != TransactionType.swap
      : widget.mode == ListingFormMode.sell;

  @override
  void initState() {
    super.initState();
    final listing = widget.editing;
    if (listing == null) return;
    _titleController.text = listing.title;
    _descriptionController.text = listing.description ?? '';
    _category = listing.listingType;
    if (listing.price != null) {
      _priceController.text = listing.price!.toStringAsFixed(2);
    }
    if (listing.quantity != null) {
      _quantityController.text = '${listing.quantity}';
    }
    _contactController.text = listing.contact ?? '';
    _swapForController.text = listing.lookingFor ?? '';
    _photos.addAll(listing.photos.map(_FormPhoto.remote));
  }

  void _removePhoto(int index) {
    setState(() {
      final removed = _photos.removeAt(index);
      if (removed.remote != null) _removedPhotoIds.add(removed.remote!.id);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _contactController.dispose();
    _swapForController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final remaining = maxPhotos - _photos.length;
    if (remaining <= 0) return;
    final picked = await ImagePicker().pickMultiImage(
      maxWidth: 1600,
      imageQuality: 85,
      limit: remaining > 1 ? remaining : null,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() {
      _photos.addAll(
        picked.take(remaining).map((file) => _FormPhoto.local(File(file.path))),
      );
      _photosMissing = false;
    });
  }

  void _stepQuantity(int delta) {
    final current = int.tryParse(_quantityController.text.trim()) ?? 0;
    final next = (current + delta).clamp(1, 100000);
    setState(() => _quantityController.text = '$next');
  }

  String? _required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    setState(() => _photosMissing = _photos.isEmpty);
    if (!formValid || _photos.isEmpty) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    if (_isEditing) {
      await _saveEdits();
      return;
    }

    try {
      final listing = await ref
          .read(apiClientProvider)
          .createListing(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            listingType: _category!,
            transactionType: _isSell
                ? TransactionType.sell
                : TransactionType.swap,
            price: _isSell
                ? double.tryParse(_priceController.text.trim())
                : null,
            quantity: _isSell
                ? int.tryParse(_quantityController.text.trim())
                : null,
            contact: _isSell ? _contactController.text.trim() : null,
            lookingFor: _isSell ? null : _swapForController.text.trim(),
            photos: [for (final photo in _photos) ?photo.file],
          );

      // Lists that show this listing won't until they refetch — nudge them
      // now so posting feels immediate.
      ref.invalidate(nearbyListingsProvider);
      ref.invalidate(myListingsProvider);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                ListingPostedScreen(listing: listing, mode: widget.mode),
          ),
        );
      }
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _saveEdits() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final updated = await ref
          .read(apiClientProvider)
          .updateListing(
            widget.editing!.id,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            listingType: _category,
            price: _isSell
                ? double.tryParse(_priceController.text.trim())
                : null,
            quantity: _isSell
                ? int.tryParse(_quantityController.text.trim())
                : null,
            contact: _isSell ? _contactController.text.trim() : null,
            lookingFor: _isSell ? null : _swapForController.text.trim(),
            newPhotos: [for (final photo in _photos) ?photo.file],
            removePhotoIds: _removedPhotoIds,
          );
      ref.invalidate(nearbyListingsProvider);
      ref.invalidate(myListingsProvider);
      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      setState(() => _errorMessage = e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final openOfferCount =
        ref
            .watch(mySwapOffersProvider)
            .valueOrNull
            ?.where((offer) => offer.status.isOpen)
            .length ??
        0;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          MarketplaceHeroHeader(
            openOfferCount: openOfferCount,
            onBack: () => Navigator.of(context).maybePop(),
            onMessagesTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const MessagesScreen())),
            onFavoritesTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const FavoritesScreen())),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isEditing
                            ? 'Edit Item'
                            : (_isSell ? 'Sell an Item' : 'Swap an Item'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isEditing
                            ? 'Change anything below, then save.'
                            : 'Add details about your item to let others know.',
                        style: const TextStyle(color: AppColors.textMuted),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],

                      const _FieldLabel(number: 1, label: 'Title of item'),
                      TextFormField(
                        key: const Key('listing-title-field'),
                        controller: _titleController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _inputDecoration(
                          _isSell
                              ? 'e.g. Tomato Seeds, Garden Compost, Hand Trowel'
                              : 'e.g. Tomato Seeds, Garden Tools, Plant Cuttings',
                        ),
                        validator: (value) =>
                            _required(value, 'Enter a title.'),
                      ),

                      const _FieldLabel(number: 2, label: 'Images'),
                      _PhotoPicker(
                        photos: _photos,
                        max: maxPhotos,
                        showError: _photosMissing,
                        onAdd: _pickPhotos,
                        onRemove: _removePhoto,
                      ),

                      const _FieldLabel(
                        number: 3,
                        label: 'Description of the item',
                      ),
                      TextFormField(
                        key: const Key('listing-description-field'),
                        controller: _descriptionController,
                        maxLines: 4,
                        minLines: 3,
                        maxLength: descriptionMaxLength,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _inputDecoration(
                          'Describe your item, its condition, variety, size, etc.',
                        ),
                        validator: (value) =>
                            _required(value, 'Add a short description.'),
                      ),

                      const _FieldLabel(number: 4, label: 'Category'),
                      _buildCategoryField(),

                      if (_isSell) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _FieldLabel(
                                    number: 5,
                                    label: 'Price per unit (£)',
                                  ),
                                  TextFormField(
                                    key: const Key('listing-price-field'),
                                    controller: _priceController,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d*\.?\d{0,2}'),
                                      ),
                                    ],
                                    decoration: _inputDecoration('e.g. 2.50')
                                        .copyWith(
                                          prefixIcon: const SizedBox(
                                            width: 40,
                                            child: Center(
                                              child: Text(
                                                '£',
                                                style: TextStyle(fontSize: 16),
                                              ),
                                            ),
                                          ),
                                        ),
                                    validator: (value) {
                                      final price = double.tryParse(
                                        value?.trim() ?? '',
                                      );
                                      if (price == null) {
                                        return 'Enter a price.';
                                      }
                                      if (price > 99999.99) return 'Too high.';
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _FieldLabel(
                                    number: 6,
                                    label: 'Quantity',
                                  ),
                                  TextFormField(
                                    key: const Key('listing-quantity-field'),
                                    controller: _quantityController,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: _inputDecoration('e.g. 10')
                                        .copyWith(
                                          suffixIcon: _QuantityStepper(
                                            onUp: () => _stepQuantity(1),
                                            onDown: () => _stepQuantity(-1),
                                          ),
                                        ),
                                    validator: (value) {
                                      final quantity = int.tryParse(
                                        value?.trim() ?? '',
                                      );
                                      if (quantity == null || quantity < 1) {
                                        return 'Enter a quantity.';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const _FieldLabel(number: 7, label: 'Contact Seller'),
                        TextFormField(
                          key: const Key('listing-contact-field'),
                          controller: _contactController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _inputDecoration('Phone number or email')
                              .copyWith(
                                prefixIcon: const Icon(
                                  Icons.phone_outlined,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          validator: (value) {
                            final contact = value?.trim() ?? '';
                            if (contact.isEmpty) {
                              return 'Enter a phone number or email.';
                            }
                            final isEmail = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(contact);
                            final digits = contact.replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            final isPhone =
                                RegExp(r'^[\d\s()+-]+$').hasMatch(contact) &&
                                digits.length >= 7;
                            return isEmail || isPhone
                                ? null
                                : 'Enter a valid phone number or email.';
                          },
                        ),
                      ] else ...[
                        const _FieldLabel(number: 5, label: 'Swap'),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mintLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.sync,
                                size: 30,
                                color: AppColors.forestDark,
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Swap',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    Text(
                                      'Exchange with another item',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const _FieldLabel(
                          number: 6,
                          label: 'What would you like to swap for?',
                        ),
                        TextFormField(
                          key: const Key('listing-swap-for-field'),
                          controller: _swapForController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _inputDecoration(
                            'e.g. Chilli seeds, Herb plants, Garden tools',
                          ),
                          validator: (value) => _required(
                            value,
                            'Say what you would like in exchange.',
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : () => Navigator.of(context).maybePop(),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.buttonMuted,
                                foregroundColor: AppColors.textDark,
                                minimumSize: const Size.fromHeight(50),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              key: const Key('create-listing-submit'),
                              onPressed: _isSubmitting ? null : _submit,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      _isEditing ? 'Save Changes' : 'Post Item',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A dropdown over the admin-managed category list (see
  /// ListingCategoryController on the backend), each with its icon.
  Widget _buildCategoryField() {
    final categoriesAsync = ref.watch(listingCategoriesProvider);

    return categoriesAsync.when(
      loading: () => InputDecorator(
        decoration: _inputDecoration(null),
        child: const Text(
          'Loading categories…',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
      error: (error, _) => InputDecorator(
        decoration: _inputDecoration(null),
        child: const Text(
          'Could not load categories',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
      data: (categories) => DropdownButtonFormField<String>(
        key: const Key('create-listing-category-field'),
        initialValue: _category,
        isExpanded: true,
        hint: const Text('Select a category'),
        decoration: _inputDecoration(null),
        icon: const Icon(Icons.keyboard_arrow_down),
        items: categories
            .map(
              (category) => DropdownMenuItem(
                value: category.name,
                child: Row(
                  children: [
                    Icon(
                      categoryIcon(category.name),
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
        validator: (value) => value == null ? 'Select a category.' : null,
        onChanged: (value) => setState(() => _category = value),
      ),
    );
  }
}

InputDecoration _inputDecoration(String? hint) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
    filled: true,
    fillColor: AppColors.surfaceContainer,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: border(AppColors.border),
    enabledBorder: border(AppColors.border),
    focusedBorder: border(AppColors.primary),
    errorBorder: border(AppColors.error),
    focusedErrorBorder: border(AppColors.error),
  );
}

/// "1. Title of item *" — the numbered field headings from the design.
class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text.rich(
        TextSpan(
          text: '$number. $label ',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: AppColors.textDark,
          ),
          children: const [
            TextSpan(
              text: '*',
              style: TextStyle(color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dashed-looking box with "Add Photos" and a row of five slots — picked
/// photos fill the slots left to right, each with a remove button.
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photos,
    required this.max,
    required this.showError,
    required this.onAdd,
    required this.onRemove,
  });

  final List<_FormPhoto> photos;
  final int max;
  final bool showError;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          key: const Key('listing-add-photos'),
          onTap: photos.length < max ? onAdd : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: showError ? AppColors.error : AppColors.border,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.photo_camera,
                  size: 34,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Add Photos',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  'Tap to add up to $max photos',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var i = 0; i < max; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1.1,
                          child: i < photos.length
                              ? Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: photos[i].file != null
                                          ? Image.file(
                                              photos[i].file!,
                                              fit: BoxFit.cover,
                                            )
                                          : Image.network(
                                              photos[i].remote!.url,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) =>
                                                  const ColoredBox(
                                                    color:
                                                        AppColors.buttonMuted,
                                                    child: Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      color:
                                                          AppColors.textMuted,
                                                    ),
                                                  ),
                                            ),
                                    ),
                                    Positioned(
                                      right: 2,
                                      top: 2,
                                      child: GestureDetector(
                                        onTap: () => onRemove(i),
                                        child: const CircleAvatar(
                                          radius: 10,
                                          backgroundColor: Colors.black54,
                                          child: Icon(
                                            Icons.close,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.buttonMuted,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        if (showError)
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 6),
            child: Text(
              'Add at least one photo.',
              style: TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({required this.onUp, required this.onDown});

  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          InkWell(
            onTap: onUp,
            child: const Icon(Icons.keyboard_arrow_up, size: 20),
          ),
          InkWell(
            onTap: onDown,
            child: const Icon(Icons.keyboard_arrow_down, size: 20),
          ),
        ],
      ),
    );
  }
}

/// One photo slot on the form: either already on the listing (editing) or
/// newly picked from the phone.
class _FormPhoto {
  const _FormPhoto.remote(ListingPhoto this.remote) : file = null;
  const _FormPhoto.local(File this.file) : remote = null;

  final ListingPhoto? remote;
  final File? file;
}
