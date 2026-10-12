import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../config/app_config.dart';
import '../../models/app_user.dart';
import '../../models/enums.dart';
import '../../models/listing.dart';
import '../../models/listing_photo.dart';
import '../../models/listing_review.dart';
import '../../models/report.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/discovery_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/safety_actions.dart';
import '../../widgets/user_avatar.dart';
import 'favorites_screen.dart';
import 'messages_screen.dart';
import 'seller_profile_screen.dart';
import 'swap_offer_thread_screen.dart';
import 'widgets/category_chips.dart';
import 'widgets/listing_owner_actions.dart';
import 'widgets/listing_price.dart';
import 'widgets/listing_thumbnail.dart';
import 'widgets/marketplace_hero_header.dart';
import 'widgets/star_rating.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listing});

  final Listing listing;

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  late Listing _listing = widget.listing;
  final _photoPageController = PageController();
  int _photoIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadFullListing();
  }

  /// The listing handed in comes from a list, which leaves out a few
  /// things only the single-listing fetch has: its current status, rating,
  /// and whether you may review it. Best-effort — on failure the screen
  /// just keeps what it was given.
  Future<void> _loadFullListing() async {
    try {
      final full = await ref.read(apiClientProvider).listing(widget.listing.id);
      if (mounted) setState(() => _listing = full);
    } catch (_) {}
  }

  @override
  void dispose() {
    _photoPageController.dispose();
    super.dispose();
  }

  Future<void> _toggleSave() async {
    final wasSaved = _listing.isSaved ?? false;
    setState(() => _listing = _listing.copyWith(isSaved: !wasSaved));
    try {
      // Also nudges the origin list (if still mounted) so the heart icon
      // there stays in sync without a manual refresh.
      await ref
          .read(nearbyListingsProvider.notifier)
          .toggleSaved(widget.listing);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _listing = _listing.copyWith(isSaved: wasSaved));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _makeOffer() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final offer = await apiClient.createSwapOffer(_listing.id);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SwapOfferThreadScreen(swapOffer: offer),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _share() {
    final priceText = listingPriceLabel(_listing);
    SharePlus.instance.share(
      ShareParams(
        text:
            '${_listing.title} — $priceText on Shobuj\n'
            '${AppConfig.listingShareUrl(_listing.id)}',
      ),
    );
  }

  void _showSafetyActions() {
    final owner = _listing.owner;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const Key('report-listing'),
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Report this listing'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                showReportSheet(
                  context,
                  target: ReportTarget.listing,
                  targetId: _listing.id,
                );
              },
            ),
            if (owner != null)
              ListTile(
                key: const Key('block-seller'),
                leading: const Icon(Icons.block, color: AppColors.error),
                title: Text(
                  'Block ${owner.name}',
                  style: const TextStyle(color: AppColors.error),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final navigator = Navigator.of(context);
                  final blocked = await confirmAndBlockUser(
                    context,
                    userId: owner.id,
                    userName: owner.name,
                  );
                  if (blocked && navigator.mounted) navigator.pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRequest = _listing.transactionType.isRequest;
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;
    final isOwnListing = _listing.owner?.id == currentUserId;
    final isSaved = _listing.isSaved ?? false;
    final isGone =
        _listing.status == ListingStatus.completed ||
        _listing.status == ListingStatus.deleted;
    final openOfferCount =
        ref
            .watch(mySwapOffersProvider)
            .valueOrNull
            ?.where((offer) => offer.status.isOpen)
            .length ??
        0;
    final area = _listing.owner?.locationLabel;
    final hasDescription =
        _listing.description != null && _listing.description!.isNotEmpty;
    final hasLookingFor =
        _listing.lookingFor != null && _listing.lookingFor!.isNotEmpty;
    // The API only returns this to the seller — buyers ask in chat.
    final hasContact =
        isOwnListing &&
        _listing.contact != null &&
        _listing.contact!.isNotEmpty;
    final hasHandover =
        _listing.handoverNote != null && _listing.handoverNote!.isNotEmpty;

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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_listing.status == ListingStatus.reserved || isGone)
                    _AvailabilityBanner(
                      reserved: _listing.status == ListingStatus.reserved,
                    ),
                  Stack(
                    children: [
                      if (isRequest && _listing.photos.isEmpty)
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.shopping_cart_outlined,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                        )
                      else
                        _PhotoGallery(
                          photos: _listing.photos,
                          controller: _photoPageController,
                          index: _photoIndex,
                          onPageChanged: (index) =>
                              setState(() => _photoIndex = index),
                        ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Row(
                          children: [
                            _FloatingIconButton(
                              icon: Icons.share_outlined,
                              onTap: _share,
                            ),
                            if (!isOwnListing) ...[
                              const SizedBox(width: 8),
                              _FloatingIconButton(
                                key: const Key('listing-safety-button'),
                                icon: Icons.flag_outlined,
                                onTap: _showSafetyActions,
                              ),
                            ],
                            const SizedBox(width: 8),
                            _FloatingIconButton(
                              key: const Key('listing-save-button'),
                              icon: isSaved
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              iconColor: isSaved
                                  ? Colors.redAccent
                                  : Colors.white,
                              onTap: _toggleSave,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    listingPriceLabel(_listing),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _listing.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        categoryIcon(_listing.listingType),
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _listing.listingType,
                        style: const TextStyle(color: AppColors.label),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      if (area != null && area.isNotEmpty)
                        _MetaItem(icon: Icons.place_outlined, text: area)
                      else if (_listing.distanceKm != null)
                        _MetaItem(
                          icon: Icons.place_outlined,
                          text:
                              '${_listing.distanceKm!.toStringAsFixed(1)} km away',
                        ),
                      _MetaItem(
                        icon: Icons.schedule,
                        text: 'Posted ${timeago.format(_listing.createdAt)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: AppColors.border),
                  if (hasDescription)
                    _DetailSection(
                      title: 'Description',
                      child: Text(
                        _listing.description!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                        ),
                      ),
                    ),
                  _DetailSection(
                    title: 'Category',
                    child: Text(_listing.listingType),
                  ),
                  if (_listing.price != null)
                    _DetailSection(
                      title: isRequest ? 'Budget' : 'Price per unit',
                      child: Text(poundFormat.format(_listing.price)),
                    ),
                  if (_listing.quantity != null)
                    _DetailSection(
                      title: 'Quantity available',
                      child: Text('${_listing.quantity}'),
                    ),
                  if (hasLookingFor)
                    _DetailSection(
                      title: isRequest
                          ? 'What they need'
                          : 'Would like to swap for',
                      child: Text(_listing.lookingFor!),
                    ),
                  if (hasContact)
                    _DetailSection(
                      title: 'Your contact (only you can see this)',
                      child: Row(
                        children: [
                          Icon(
                            _listing.contact!.contains('@')
                                ? Icons.email_outlined
                                : Icons.phone_outlined,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SelectableText(
                              _listing.contact!,
                              key: const Key('listing-contact'),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copy',
                            icon: const Icon(Icons.copy, size: 18),
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: _listing.contact!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Contact copied')),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  if (hasHandover)
                    _DetailSection(
                      title: 'Handover',
                      child: Text(_listing.handoverNote!),
                    ),

                  // --- Seller Profile Card ---
                  if (_listing.owner != null) ...[
                    const SizedBox(height: 20),
                    _SellerCard(owner: _listing.owner!),
                  ],

                  const SizedBox(height: 16),
                  _ReviewsSection(
                    listingId: _listing.id,
                    currentUserId: currentUserId,
                    isOwnListing: isOwnListing,
                    canReview: _listing.canReview ?? false,
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
                            'inspect any plant material before you accept it.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainer,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: isOwnListing
                ? ListingOwnerBar(
                    listing: _listing,
                    onChanged: (updated) => setState(() => _listing = updated),
                    onDeleted: () => Navigator.of(context).maybePop(),
                  )
                : FilledButton.icon(
                    key: const Key('listing-cta'),
                    onPressed: isGone ? null : _makeOffer,
                    icon: const Icon(Icons.chat_bubble_outline, size: 20),
                    label: Text(
                      isGone ? 'No longer available' : 'Message Seller',
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// "Reserved" while a deal on this listing is in progress, or "No longer
/// available" once one is completed — see SwapOfferController::updateStatus().
class _AvailabilityBanner extends StatelessWidget {
  const _AvailabilityBanner({required this.reserved});

  final bool reserved;

  @override
  Widget build(BuildContext context) {
    final color = reserved ? Colors.amber.shade800 : AppColors.textMuted;
    return Container(
      key: const Key('listing-availability-banner'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            reserved ? Icons.handshake_outlined : Icons.check_circle_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reserved
                  ? 'Reserved: a deal on this is in progress. If you have '
                        'an offer here, you can still open it.'
                  : 'No longer available: this deal has been completed.',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// The main photo (swipeable) with a strip of thumbnails underneath when
/// there's more than one — tapping a thumbnail jumps to it.
class _PhotoGallery extends StatelessWidget {
  const _PhotoGallery({
    required this.photos,
    required this.controller,
    required this.index,
    required this.onPageChanged,
  });

  final List<ListingPhoto> photos;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPageChanged;

  static const _height = 240.0;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const ListingThumbnail(
        url: null,
        size: double.infinity,
        height: _height,
        borderRadius: 14,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: _height,
            child: PageView.builder(
              controller: controller,
              onPageChanged: onPageChanged,
              itemCount: photos.length,
              itemBuilder: (context, i) => ListingThumbnail(
                url: photos[i].url,
                size: double.infinity,
                height: _height,
                borderRadius: 0,
              ),
            ),
          ),
        ),
        if (photos.length > 1) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => controller.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: i == index
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListingThumbnail(
                    url: photos[i].url,
                    size: 66,
                    height: 48,
                    borderRadius: 6,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// A bold heading with its value underneath — "Description", "Category",
/// "Price per unit", "Quantity available", ...
class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 4),
          DefaultTextStyle.merge(
            style: const TextStyle(color: AppColors.label, fontSize: 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _FloatingIconButton extends StatelessWidget {
  const _FloatingIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.forestDark.withValues(alpha: 0.7),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.owner});

  final AppUser owner;

  /// A truthful stand-in for a seller subtitle: derived from their real
  /// growing setup / experience level rather than an invented title like
  /// "Certified Agronomist" — null when neither is set on their profile.
  String? get _roleLabel {
    final setup = owner.growingSetup?.label;
    if (setup != null) return '$setup Grower';
    final level = owner.experienceLevel?.label;
    if (level != null) return '$level Grower';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isVerified = owner.isVerified ?? false;
    final role = _roleLabel;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'LISTED BY GROWER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              if (isVerified)
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 13, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Identity Verified',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => openUserProfile(context, owner.id),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    UserAvatar(
                      name: owner.name,
                      avatarUrl: owner.avatarUrl,
                      radius: 24,
                    ),
                    if (isVerified)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        owner.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (role != null)
                        Text(
                          role,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => openUserProfile(context, owner.id),
              icon: const Icon(Icons.person_outline, size: 16),
              label: const Text('View Seller Profile'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Star rating + written reviews for a listing — reads/writes
/// [listingReviewsProvider], keyed by [listingId]. The listing's owner can't
/// review their own listing (same rule the backend enforces) but can delete
/// any review left on it, same moderation pattern as a post author deleting
/// comments on their own post.
class _ReviewsSection extends ConsumerWidget {
  const _ReviewsSection({
    required this.listingId,
    required this.currentUserId,
    required this.isOwnListing,
    required this.canReview,
  });

  final int listingId;
  final int? currentUserId;
  final bool isOwnListing;

  /// Reviews are only open to someone who completed a deal for this
  /// listing (ListingReviewController::store() enforces the same rule).
  final bool canReview;

  Future<void> _openReviewSheet(
    BuildContext context,
    WidgetRef ref, {
    ListingReview? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _WriteReviewSheet(listingId: listingId, existing: existing),
    );
  }

  Future<void> _deleteReview(
    BuildContext context,
    WidgetRef ref,
    ListingReview review,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(listingReviewsProvider(listingId).notifier)
          .deleteReview(review.id);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(listingReviewsProvider(listingId));
    final reviews = reviewsAsync.valueOrNull ?? [];
    final myReview = currentUserId == null
        ? null
        : reviews.cast<ListingReview?>().firstWhere(
            (r) => r?.reviewer?.id == currentUserId,
            orElse: () => null,
          );
    final average = reviews.isEmpty
        ? 0.0
        : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.reviews_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Reviews',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const Spacer(),
              if (!isOwnListing && (canReview || myReview != null))
                TextButton.icon(
                  key: const Key('write-review-button'),
                  onPressed: () =>
                      _openReviewSheet(context, ref, existing: myReview),
                  icon: Icon(
                    myReview != null ? Icons.edit_outlined : Icons.star_outline,
                    size: 16,
                  ),
                  label: Text(
                    myReview != null ? 'Edit Review' : 'Write a Review',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!isOwnListing && !canReview && myReview == null)
            const Padding(
              key: Key('review-after-deal-hint'),
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'You can leave a review after completing a deal for this '
                'listing.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ),
          switch (reviewsAsync) {
            AsyncData(:final value) when value.isEmpty => const Text(
              'No reviews yet — be the first to leave one.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            AsyncData() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StarRatingDisplay(rating: average),
                    const SizedBox(width: 8),
                    Text(
                      '${average.toStringAsFixed(1)} '
                      '(${reviews.length} review${reviews.length == 1 ? '' : 's'})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                for (final review in reviews) ...[
                  const SizedBox(height: 12),
                  _ReviewTile(
                    review: review,
                    canDelete:
                        review.reviewer?.id == currentUserId || isOwnListing,
                    onDelete: () => _deleteReview(context, ref, review),
                  ),
                ],
              ],
            ),
            AsyncError() => const Text(
              'Could not load reviews.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            _ => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          },
        ],
      ),
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({
    required this.review,
    required this.canDelete,
    required this.onDelete,
  });

  final ListingReview review;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final reviewer = review.reviewer;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(
          name: reviewer?.name ?? 'Grower',
          avatarUrl: reviewer?.avatarUrl,
          radius: 16,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      reviewer?.name ?? 'Grower',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    timeago.format(review.createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (canDelete)
                    InkWell(
                      key: const Key('delete-review-button'),
                      onTap: onDelete,
                      child: const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              StarRatingDisplay(rating: review.rating.toDouble(), size: 14),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  review.comment!,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for writing (or editing) a review — a plain star picker plus
/// an optional comment. Submitting is an upsert on the backend, so editing
/// an existing review reuses the same call as writing a new one.
class _WriteReviewSheet extends ConsumerStatefulWidget {
  const _WriteReviewSheet({required this.listingId, this.existing});

  final int listingId;
  final ListingReview? existing;

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  late int _rating = widget.existing?.rating ?? 5;
  late final _commentController = TextEditingController(
    text: widget.existing?.comment ?? '',
  );
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(listingReviewsProvider(widget.listingId).notifier)
          .submitReview(
            rating: _rating,
            comment: _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing != null ? 'Edit Your Review' : 'Write a Review',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Center(
              child: StarRatingInput(
                rating: _rating,
                onChanged: (value) => setState(() => _rating = value),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                hintText: 'Share details about your experience (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.existing != null
                            ? 'Update Review'
                            : 'Submit Review',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
