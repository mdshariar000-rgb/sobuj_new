import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/app_user.dart';
import '../../models/enums.dart';
import '../../models/listing.dart';
import '../../models/listing_photo.dart';
import '../../models/report.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/discovery_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/safety_actions.dart';
import '../../widgets/user_avatar.dart';
import 'seller_profile_screen.dart';
import 'swap_offer_thread_screen.dart';
import 'widgets/listing_thumbnail.dart';

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
    final priceText = _listing.price != null
        ? NumberFormat.simpleCurrency().format(_listing.price)
        : _listing.transactionType.label;
    SharePlus.instance.share(
      ShareParams(text: '${_listing.title} — $priceText on Agro Hub'),
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

  String _ctaLabel(TransactionType type) {
    switch (type) {
      case TransactionType.sell:
      case TransactionType.swapOrCash:
        return 'Contact Author';
      case TransactionType.free:
        return 'Request Item';
      case TransactionType.swap:
        return 'Propose Trade';
      case TransactionType.wanted:
        return 'I Have This';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRequest = _listing.transactionType.isRequest;
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;
    final isOwnListing = _listing.owner?.id == currentUserId;
    final isSaved = _listing.isSaved ?? false;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              if (!isRequest)
                _PhotoCarousel(
                  photos: _listing.photos,
                  controller: _photoPageController,
                  index: _photoIndex,
                  onPageChanged: (index) => setState(() => _photoIndex = index),
                )
              else
                Container(
                  height: 200,
                  color: AppColors.forestPanel,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.handyman_outlined,
                    size: 48,
                    color: AppColors.mint,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Listing Information Card ---
                    Container(
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _StatusPill(
                                      label: isRequest
                                          ? 'Wanted Item'
                                          : _listing.transactionType.label,
                                    ),
                                    if (_listing.condition != null)
                                      _StatusPill(
                                        label: _listing.condition!.label,
                                        muted: true,
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    size: 12,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Listed ${timeago.format(_listing.createdAt)}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _listing.title,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: AppColors.forestDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                _listing.price != null
                                    ? (isRequest
                                          ? 'Up to ${NumberFormat.simpleCurrency().format(_listing.price)}'
                                          : NumberFormat.simpleCurrency()
                                                .format(_listing.price))
                                    : (_listing.transactionType ==
                                              TransactionType.free
                                          ? 'Free'
                                          : _listing.transactionType.label),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_listing.price != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  _listing.transactionType ==
                                          TransactionType.swapOrCash
                                      ? 'Open to Offers'
                                      : 'Fixed Price',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 12),
                          if (_listing.location != null) ...[
                            Row(
                              children: [
                                const Icon(
                                  Icons.place_outlined,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _listing.distanceKm != null
                                        ? '${_listing.distanceKm!.toStringAsFixed(1)} km away'
                                        : 'Approximate pickup area',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            children: [
                              const Icon(
                                Icons.visibility_outlined,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${_listing.viewsCount} views',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  '•',
                                  style: TextStyle(color: AppColors.border),
                                ),
                              ),
                              Text(
                                'ID: #AG-${_listing.id}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // --- Seller Profile Card ---
                    if (_listing.owner != null) ...[
                      const SizedBox(height: 16),
                      _SellerCard(owner: _listing.owner!),
                    ],

                    // --- Description & Care Notes ---
                    if ((_listing.description != null &&
                            _listing.description!.isNotEmpty) ||
                        (_listing.lookingFor != null &&
                            _listing.lookingFor!.isNotEmpty) ||
                        (_listing.handoverNote != null &&
                            _listing.handoverNote!.isNotEmpty)) ...[
                      const SizedBox(height: 16),
                      Container(
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
                                  Icons.menu_book_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Description & Notes',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            if (_listing.description != null &&
                                _listing.description!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                _listing.description!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                ),
                              ),
                            ],
                            if (_listing.lookingFor != null &&
                                _listing.lookingFor!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                isRequest
                                    ? 'What they need'
                                    : 'Willing to accept',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(_listing.lookingFor!),
                            ],
                            if (_listing.handoverNote != null &&
                                _listing.handoverNote!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Text(
                                'Handover',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(_listing.handoverNote!),
                            ],
                          ],
                        ),
                      ),
                    ],

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
                    const SizedBox(height: 96),
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            left: 16,
            top: MediaQuery.of(context).padding.top + 10,
            child: _FloatingIconButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.of(context).padding.top + 10,
            child: Row(
              children: [
                _FloatingIconButton(icon: Icons.share_outlined, onTap: _share),
                const SizedBox(width: 10),
                _FloatingIconButton(
                  icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                  iconColor: isSaved ? AppColors.mint : Colors.white,
                  onTap: _toggleSave,
                ),
                if (!isOwnListing) ...[
                  const SizedBox(width: 10),
                  _FloatingIconButton(
                    key: const Key('listing-safety-button'),
                    icon: Icons.flag_outlined,
                    onTap: _showSafetyActions,
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
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
                  ? const Text(
                      'This is your own listing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  : Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.buttonMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: IconButton(
                            onPressed: _toggleSave,
                            icon: Icon(
                              isSaved ? Icons.bookmark : Icons.bookmark_border,
                              color: AppColors.forestDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _makeOffer,
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 18,
                            ),
                            label: Text(_ctaLabel(_listing.transactionType)),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
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

class _PhotoCarousel extends StatelessWidget {
  const _PhotoCarousel({
    required this.photos,
    required this.controller,
    required this.index,
    required this.onPageChanged,
  });

  final List<ListingPhoto> photos;
  final PageController controller;
  final int index;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) {
      return const ListingThumbnail(
        url: null,
        size: double.infinity,
        height: 280,
        borderRadius: 0,
      );
    }

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: controller,
            onPageChanged: onPageChanged,
            itemCount: photos.length,
            itemBuilder: (context, i) => ListingThumbnail(
              url: photos[i].url,
              size: double.infinity,
              height: 280,
              borderRadius: 0,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.35),
              ],
              stops: const [0.6, 1.0],
            ),
          ),
          child: const SizedBox(height: 280, width: double.infinity),
        ),
        if (photos.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < photos.length; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: i == index
                          ? AppColors.mint
                          : Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: muted ? AppColors.buttonMuted : AppColors.mint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: muted ? AppColors.label : AppColors.forestDark,
        ),
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
