import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/listing.dart';
import '../../models/swap_offer.dart';
import '../../providers/auth_providers.dart';
import '../../providers/discovery_providers.dart';
import '../../theme/app_colors.dart';
import 'create_listing_screen.dart';
import 'seller_profile_screen.dart';
import 'swap_offer_thread_screen.dart';
import 'widgets/category_chips.dart' show categoryIcon;
import 'widgets/create_listing_banner.dart';
import 'widgets/listing_thumbnail.dart';
import '../../widgets/shimmer.dart';

enum _MessagesFilter { all, buying, selling, archived }

enum _MessagesSort {
  recent('Sort: Recent first'),
  oldest('Sort: Oldest first');

  const _MessagesSort(this.label);
  final String label;
}

/// The real inbox behind the header's message icon — every swap offer
/// involving the signed-in user, either as buyer or seller, with each
/// thread's genuine most-recent message as a preview. Unread counts are
/// real too (see SwapOfferResource::unread_count / MessageController::index()
/// marking messages read on open); "Awaiting your reply" is derived
/// honestly from whether the other party sent the last message.
class MessagesScreen extends ConsumerStatefulWidget {
  const MessagesScreen({super.key});

  @override
  ConsumerState<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends ConsumerState<MessagesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  _MessagesFilter _filter = _MessagesFilter.all;
  _MessagesSort _sort = _MessagesSort.recent;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SwapOffer> _visibleOffers(List<SwapOffer> offers, int? currentUserId) {
    var result = offers.where((offer) {
      switch (_filter) {
        case _MessagesFilter.all:
          return true;
        case _MessagesFilter.buying:
          return offer.requester?.id == currentUserId;
        case _MessagesFilter.selling:
          return offer.listing?.owner?.id == currentUserId;
        case _MessagesFilter.archived:
          return !offer.status.isOpen;
      }
    }).toList();

    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((offer) {
        final isBuying = offer.requester?.id == currentUserId;
        final otherParty = isBuying ? offer.listing?.owner : offer.requester;
        final title = offer.listing?.title.toLowerCase() ?? '';
        final name = otherParty?.name.toLowerCase() ?? '';
        return title.contains(query) || name.contains(query);
      }).toList();
    }

    result.sort((a, b) {
      final aTime = a.lastMessage?.createdAt ?? a.createdAt;
      final bTime = b.lastMessage?.createdAt ?? b.createdAt;
      return _sort == _MessagesSort.recent
          ? bTime.compareTo(aTime)
          : aTime.compareTo(bTime);
    });

    return result;
  }

  void _showSortMenu() async {
    final selected = await showModalBottomSheet<_MessagesSort>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final sort in _MessagesSort.values)
              ListTile(
                title: Text(sort.label),
                trailing: _sort == sort
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(sort),
              ),
          ],
        ),
      ),
    );
    if (selected != null) setState(() => _sort = selected);
  }

  void _showSafeTradeTips() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Community Safe Trade'),
        content: const Text(
          'Meet in a public place when possible, during daylight hours. '
          'Inspect any plant material for pests or disease before you '
          'accept it, and never send payment before you\'ve seen the item.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(mySwapOffersProvider);
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _Header(onFilterTap: _showSortMenu),
          Container(
            color: AppColors.forestDark,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search conversations, crops, or sellers…',
                hintStyle: const TextStyle(color: AppColors.textOnDarkMuted),
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.textOnDarkMuted,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Container(
            color: AppColors.forestDark,
            padding: const EdgeInsets.only(bottom: 12),
            child: offersAsync.maybeWhen(
              data: (offers) => _FilterChipsRow(
                filter: _filter,
                buyingCount: offers
                    .where((o) => o.requester?.id == currentUserId)
                    .length,
                sellingCount: offers
                    .where((o) => o.listing?.owner?.id == currentUserId)
                    .length,
                archivedCount: offers.where((o) => !o.status.isOpen).length,
                onSelect: (filter) => setState(() => _filter = filter),
              ),
              orElse: () => const SizedBox(height: 40),
            ),
          ),
          Expanded(
            child: offersAsync.when(
              loading: () => const ShimmerCardList(thumbSize: 64, lines: 3),
              error: (error, _) => Center(child: Text('$error')),
              data: (offers) {
                final visible = _visibleOffers(offers, currentUserId);

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(mySwapOffersProvider.future),
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _SafeTradeBanner(onTipsTap: _showSafeTradeTips),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'ACTIVE CONVERSATIONS',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _sort == _MessagesSort.recent
                                  ? 'Sorted by recent'
                                  : 'Sorted by oldest',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            offers.isEmpty
                                ? 'No conversations yet — tap Message '
                                      'Seller on a listing to start one.'
                                : 'No conversations match your filters.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      else
                        for (final offer in visible)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: _ConversationCard(
                              offer: offer,
                              currentUserId: currentUserId,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SwapOfferThreadScreen(swapOffer: offer),
                                ),
                              ),
                            ),
                          ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: CreateListingBanner(
                          onCreate: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateListingScreen(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onFilterTap});

  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.forestDark,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'Marketplace Messages',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: onFilterTap,
                icon: const Icon(Icons.tune, size: 14, color: Colors.white),
                label: const Text(
                  'Filter',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size.zero,
                  side: const BorderSide(color: AppColors.textOnDarkMuted),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow({
    required this.filter,
    required this.buyingCount,
    required this.sellingCount,
    required this.archivedCount,
    required this.onSelect,
  });

  final _MessagesFilter filter;
  final int buyingCount;
  final int sellingCount;
  final int archivedCount;
  final ValueChanged<_MessagesFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _FilterChip(
            label: 'All Messages',
            selected: filter == _MessagesFilter.all,
            onTap: () => onSelect(_MessagesFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Buying',
            count: buyingCount,
            selected: filter == _MessagesFilter.buying,
            onTap: () => onSelect(_MessagesFilter.buying),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Selling',
            count: sellingCount,
            selected: filter == _MessagesFilter.selling,
            onTap: () => onSelect(_MessagesFilter.selling),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Archived',
            count: archivedCount,
            selected: filter == _MessagesFilter.archived,
            onTap: () => onSelect(_MessagesFilter.archived),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  // Drawn by hand rather than with ChoiceChip: the app theme's chip colours
  // are for light screens and turned the unselected chips white-on-white on
  // this dark header.
  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.forestDark : Colors.white;
    return Material(
      color: selected ? AppColors.mint : Colors.white.withValues(alpha: 0.10),
      shape: StadiumBorder(
        side: BorderSide(
          color: selected
              ? AppColors.mint
              : Colors.white.withValues(alpha: 0.35),
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check, size: 16, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                count != null ? '$label ($count)' : label,
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafeTradeBanner extends StatelessWidget {
  const _SafeTradeBanner({required this.onTipsTap});

  final VoidCallback onTipsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Safe Trade Active',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  'Meet in public, during daylight hours',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onTipsTap, child: const Text('Tips')),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({
    required this.offer,
    required this.currentUserId,
    required this.onTap,
  });

  final SwapOffer offer;
  final int? currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isBuying = offer.requester?.id == currentUserId;
    final otherParty = isBuying ? offer.listing?.owner : offer.requester;
    final lastMessage = offer.lastMessage;
    final lastTime = lastMessage?.createdAt ?? offer.createdAt;
    final isAwaitingReply =
        lastMessage != null &&
        !lastMessage.isSystemEvent &&
        lastMessage.senderId != currentUserId;
    final unreadCount = offer.unreadCount ?? 0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: unreadCount > 0
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.primary),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ListingThumbnail(
                    url: offer.listing?.thumbnailUrl,
                    size: 56,
                    borderRadius: 12,
                  ),
                  Positioned(
                    left: -4,
                    bottom: -4,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: isBuying
                          ? AppColors.forestDark
                          : AppColors.primary,
                      child: Text(
                        isBuying ? 'B' : 'S',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                openUserProfile(context, otherParty?.id),
                            child: Text(
                              otherParty?.name ?? 'Unknown grower',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          timeago.format(lastTime),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: unreadCount > 0
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (offer.listing != null)
                      _ListingPill(listing: offer.listing!),
                    const SizedBox(height: 6),
                    Text(
                      _previewText(lastMessage),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontWeight: isAwaitingReply
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    if (offer.listing?.handoverNote != null &&
                        offer.listing!.handoverNote!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              offer.listing!.handoverNote!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (isAwaitingReply || !offer.status.isOpen) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: isAwaitingReply
                            ? FilledButton(
                                onPressed: onTap,
                                style: FilledButton.styleFrom(
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                ),
                                child: const Text('Reply'),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  offer.status.label,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewText(SwapOfferLastMessage? message) {
    if (message == null) return 'No messages yet.';
    if (message.isSystemEvent) return message.body ?? '';
    if (message.body == null || message.body!.isEmpty) {
      return message.hasImage ? '📷 Photo' : '';
    }
    return message.body!;
  }
}

class _ListingPill extends StatelessWidget {
  const _ListingPill({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final priceText = listing.price != null
        ? NumberFormat.simpleCurrency(name: 'GBP').format(listing.price)
        : listing.transactionType.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(categoryIcon(listing.listingType), size: 12),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '${listing.title} ($priceText)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
