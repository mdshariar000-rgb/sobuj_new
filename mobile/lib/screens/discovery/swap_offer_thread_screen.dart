import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/app_user.dart';
import '../../models/listing.dart';
import '../../models/message_reaction.dart';
import '../../models/message_reply.dart';
import '../../models/report.dart';
import '../../models/swap_message.dart';
import '../../models/swap_offer.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/discovery_providers.dart';
import '../../providers/feed_marketplace_providers.dart';
import '../../services/api_exception.dart';
import '../../services/swap_offer_realtime_channel.dart';
import '../../theme/app_colors.dart';
import '../../widgets/chat_image_grid.dart';
import '../../widgets/chat_reactions.dart';
import '../../widgets/chat_reply.dart';
import '../../widgets/pending_images_strip.dart';
import '../../widgets/safety_actions.dart';
import '../../widgets/user_avatar.dart';
import 'listing_detail_screen.dart';
import 'seller_profile_screen.dart';
import 'widgets/deal_bar.dart';
import 'widgets/listing_price.dart';
import 'widgets/listing_thumbnail.dart';
import '../../widgets/shimmer.dart';

/// A single swap offer's message thread — real GET/POST against
/// SwapOfferController/MessageController, with live delivery over a
/// per-thread Reverb WebSocket channel (see [SwapOfferRealtimeChannel]):
/// new messages and status changes from the other party arrive the moment
/// they're sent, no manual refresh needed.
class SwapOfferThreadScreen extends ConsumerStatefulWidget {
  const SwapOfferThreadScreen({super.key, required this.swapOffer});

  final SwapOffer swapOffer;

  @override
  ConsumerState<SwapOfferThreadScreen> createState() =>
      _SwapOfferThreadScreenState();
}

class _SwapOfferThreadScreenState extends ConsumerState<SwapOfferThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _composerFocusNode = FocusNode();
  bool _isSending = false;

  /// Photos picked for the next message, shown above the composer.
  final List<File> _pendingImages = [];

  /// The message the next one answers, shown above the composer.
  MessageReply? _replyingTo;

  /// Lets a tapped reply quote scroll back to the message it quotes.
  final _messageKeys = <int, GlobalKey>{};
  late SwapOffer _swapOffer = widget.swapOffer;
  SwapOfferRealtimeChannel? _realtime;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    final channel = ref.read(swapOfferRealtimeChannelProvider(_swapOffer.id))
      ..onMessage = (message) {
        ref
            .read(swapOfferMessagesProvider(_swapOffer.id).notifier)
            .receiveMessage(message);
      }
      ..onReactions = (messageId, reactions) {
        ref
            .read(swapOfferMessagesProvider(_swapOffer.id).notifier)
            .applyReactions(messageId, reactions);
      }
      ..onStatusUpdated = (status) {
        if (mounted) {
          setState(() => _swapOffer = _swapOffer.copyWith(status: status));
        }
      };
    _realtime = channel;
    channel.connect();

    // Re-anchor to the bottom once the keyboard finishes opening — a plain
    // ListView doesn't automatically follow the shrinking viewport, so
    // without this the latest messages end up hidden behind the keyboard
    // the moment you tap in to type.
    _composerFocusNode.addListener(() {
      if (_composerFocusNode.hasFocus) _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _realtime?.dispose();
    _controller.dispose();
    _scrollController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  /// Always schedules the scroll for the next frame rather than bailing out
  /// when `_scrollController` isn't attached yet — that guard used to skip
  /// scheduling entirely on the very first load (the ListView doesn't exist
  /// until this same frame finishes building), which is exactly why opening
  /// a thread used to land wherever the list happened to start rather than
  /// at the real latest message.
  /// [animated] is false for the thread's initial open — like WhatsApp, it
  /// should already be sitting at the latest message with no visible scroll
  /// animation, not visibly scroll down from wherever the list started.
  /// True for a genuinely new message arriving while already viewing it.
  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    final images = List<File>.of(_pendingImages);
    final replyTo = _replyingTo;
    if (body.isEmpty && images.isEmpty) return;

    _controller.clear();
    setState(() {
      _pendingImages.clear();
      _replyingTo = null;
      _isSending = true;
    });
    try {
      await ref
          .read(swapOfferMessagesProvider(_swapOffer.id).notifier)
          .sendMessage(
            body: body.isEmpty ? null : body,
            images: images,
            replyTo: replyTo,
          );
    } on ApiException catch (e) {
      if (mounted) {
        // Put back what didn't send, unless the user already started over.
        if (_controller.text.isEmpty) _controller.text = body;
        if (_pendingImages.isEmpty) {
          setState(() => _pendingImages.addAll(images));
        }
        if (_replyingTo == null && replyTo != null) {
          setState(() => _replyingTo = replyTo);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// Static (not AI-personalized) canned replies, same pattern as the Group
  /// Chat quick-reply row — sends a real message, just with pre-filled text.
  Future<void> _sendQuickReply(String text) async {
    setState(() => _isSending = true);
    try {
      await ref
          .read(swapOfferMessagesProvider(_swapOffer.id).notifier)
          .sendMessage(body: text);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _react(int messageId, String emoji) async {
    try {
      await ref
          .read(swapOfferMessagesProvider(_swapOffer.id).notifier)
          .react(messageId, emoji);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _startReply(SwapMessage message) {
    setState(
      () => _replyingTo = MessageReply(
        id: message.id,
        body: message.body,
        senderName: message.sender?.name,
        imageUrl: message.imageUrls.firstOrNull,
        imageCount: message.imageUrls.length + message.localImages.length,
      ),
    );
    _composerFocusNode.requestFocus();
  }

  /// Scrolls to the quoted message — directly if it's built, otherwise to
  /// roughly where it sits in the list first so the lazy list builds it.
  void _scrollToMessage(int messageId, List<SwapMessage> messages) {
    void reveal() {
      final target = _messageKeys[messageId]?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.3,
          duration: const Duration(milliseconds: 300),
        );
      }
    }

    if (_messageKeys[messageId]?.currentContext != null) {
      reveal();
      return;
    }
    final index = messages.indexWhere((m) => m.id == messageId);
    if (index < 0 || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    _scrollController.jumpTo(
      position.maxScrollExtent * index / messages.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => reveal());
  }

  /// Adds photos to the next message rather than sending straight away, so
  /// several can go together, with a caption.
  Future<void> _addImages() async {
    final remaining = maxChatImages - _pendingImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can send up to $maxChatImages photos at a time.'),
        ),
      );
      return;
    }

    final picked = await pickChatImagesFromGallery(remaining: remaining);
    if (picked.isEmpty || !mounted) return;
    setState(() => _pendingImages.addAll(picked));
  }

  Future<void> _updateStatus(
    SwapOfferStatus status, {
    int? quantitySold,
  }) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final updated = await apiClient.updateSwapOfferStatus(
        _swapOffer.id,
        status,
        quantitySold: quantitySold,
      );
      if (mounted) setState(() => _swapOffer = updated);
      // Accepting reserves the listing, and cancelling or completing the deal
      // releases or closes it, so the marketplace lists are out of date.
      if (status == SwapOfferStatus.accepted ||
          status == SwapOfferStatus.canceled ||
          status == SwapOfferStatus.completed) {
        if (ref.exists(nearbyListingsProvider)) {
          ref.invalidate(nearbyListingsProvider);
        }
        if (ref.exists(feedMarketplaceProvider)) {
          ref.invalidate(feedMarketplaceProvider);
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(swapOfferMessagesProvider(_swapOffer.id));
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;
    final listing = _swapOffer.listing;
    final isRequester = _swapOffer.requester?.id == currentUserId;
    final otherParty = isRequester ? listing?.owner : _swapOffer.requester;

    ref.listen(swapOfferMessagesProvider(_swapOffer.id), (previous, next) {
      final count = next.valueOrNull?.length ?? 0;
      if (count > _lastMessageCount) {
        // No prior data means this is the thread's first-ever render of
        // real messages (opening it), not a message arriving mid-session.
        final isInitialLoad = previous?.valueOrNull == null;
        _lastMessageCount = count;
        _scrollToBottom(animated: !isInitialLoad);
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Opening this thread marked its messages read on the server (see
        // MessageController::index()) — refresh the inbox so its unread
        // badges reflect that the moment the user's back on it.
        if (didPop) ref.invalidate(mySwapOffersProvider);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            _ThreadHeader(
              otherParty: otherParty,
              isOwner: !isRequester,
              status: _swapOffer.status,
              onUpdateStatus: _updateStatus,
              onViewListing: listing == null
                  ? null
                  : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ListingDetailScreen(listing: listing),
                      ),
                    ),
            ),
            if (isRequester &&
                listing != null &&
                _swapOffer.status == SwapOfferStatus.completed)
              _ReviewPrompt(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ListingDetailScreen(listing: listing),
                  ),
                ),
              ),
            if (listing != null)
              _PinnedListingCard(
                listing: listing,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ListingDetailScreen(listing: listing),
                  ),
                ),
              ),
            if (listing != null)
              DealBar(
                swapOffer: _swapOffer,
                isSeller: !isRequester,
                onUpdateStatus: _updateStatus,
              ),
            const _SafetyNotice(),
            Expanded(
              child: messagesAsync.when(
                loading: () => const ShimmerChat(),
                error: (error, _) => Center(child: Text('$error')),
                data: (messages) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final previous = index - 1 >= 0
                          ? messages[index - 1]
                          : null;
                      final showDateDivider =
                          previous == null ||
                          !_isSameDay(previous.createdAt, message.createdAt);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDateDivider)
                            _DateDivider(date: message.createdAt),
                          KeyedSubtree(
                            key: _messageKeys.putIfAbsent(
                              message.id,
                              GlobalKey.new,
                            ),
                            child: _MessageBubble(
                              message: message,
                              isMine: message.sender?.id == currentUserId,
                              onReply: () => _startReply(message),
                              myUserId: currentUserId,
                              onReact: (emoji) => _react(message.id, emoji),
                              onQuoteTap: message.replyToId == null
                                  ? null
                                  : () => _scrollToMessage(
                                      message.replyToId!,
                                      messages,
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            if (_swapOffer.status.isOpen)
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    _QuickReplyChip(
                      label: '👍',
                      onTap: _isSending ? null : () => _sendQuickReply('👍'),
                    ),
                    const SizedBox(width: 8),
                    _QuickReplyChip(
                      label: 'Sounds good!',
                      onTap: _isSending
                          ? null
                          : () => _sendQuickReply('Sounds good!'),
                    ),
                    const SizedBox(width: 8),
                    _QuickReplyChip(
                      label: 'Still available?',
                      onTap: _isSending
                          ? null
                          : () => _sendQuickReply('Is this still available?'),
                    ),
                  ],
                ),
              ),
            if (_replyingTo != null)
              ReplyComposerBar(
                reply: _replyingTo!,
                onCancel: () => setState(() => _replyingTo = null),
              ),
            PendingImagesStrip(
              files: _pendingImages,
              onRemove: (index) =>
                  setState(() => _pendingImages.removeAt(index)),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _isSending ? null : _addImages,
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Attach photos',
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _composerFocusNode,
                        decoration: InputDecoration(
                          hintText: otherParty != null
                              ? 'Message ${otherParty.name} about this listing...'
                              : 'Write a message...',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _isSending ? null : _send,
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String? _roleLabel(AppUser? user) {
  final setup = user?.growingSetup?.label;
  if (setup != null) return '$setup Grower';
  final level = user?.experienceLevel?.label;
  if (level != null) return '$level Grower';
  return null;
}

/// Shown to the buyer once a deal is completed: reviews are only open to
/// people who completed a deal for the listing.
class _ReviewPrompt extends StatelessWidget {
  const _ReviewPrompt({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: InkWell(
        key: const Key('swap-review-prompt'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              const Icon(Icons.star_outline, color: AppColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Deal completed. How did it go?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                'Leave a review',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.otherParty,
    required this.isOwner,
    required this.status,
    required this.onUpdateStatus,
    required this.onViewListing,
  });

  final AppUser? otherParty;
  final bool isOwner;
  final SwapOfferStatus status;
  final ValueChanged<SwapOfferStatus> onUpdateStatus;
  final VoidCallback? onViewListing;

  /// Mirrors SwapOfferPolicy::respond() closely enough to decide which
  /// actions to *offer* — the server is still the source of truth and will
  /// reject anything this gets wrong.
  List<(String, SwapOfferStatus)> get _actions {
    switch (status) {
      case SwapOfferStatus.pending:
        return isOwner
            ? [
                ('Accept Offer', SwapOfferStatus.accepted),
                ('Decline Offer', SwapOfferStatus.declined),
              ]
            : [('Cancel Offer', SwapOfferStatus.canceled)];
      case SwapOfferStatus.countered:
        return isOwner
            ? [('Cancel Offer', SwapOfferStatus.canceled)]
            : [
                ('Accept Offer', SwapOfferStatus.accepted),
                ('Decline Offer', SwapOfferStatus.declined),
              ];
      case SwapOfferStatus.accepted:
        return [
          ('Mark as Completed', SwapOfferStatus.completed),
          ('Cancel Offer', SwapOfferStatus.canceled),
        ];
      case SwapOfferStatus.declined:
      case SwapOfferStatus.completed:
      case SwapOfferStatus.canceled:
        return const [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = otherParty?.name ?? 'Offer';
    final role = _roleLabel(otherParty);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.forestDark, AppColors.forestPanel],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 8, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              GestureDetector(
                onTap: () => openUserProfile(context, otherParty?.id),
                child: UserAvatar(
                  name: name,
                  avatarUrl: otherParty?.avatarUrl,
                  radius: 18,
                  fallbackColor: AppColors.mint.withValues(alpha: 0.18),
                  fallbackTextColor: AppColors.mint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => openUserProfile(context, otherParty?.id),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isOwner)
                        const Text(
                          'Message Seller',
                          style: TextStyle(
                            color: AppColors.mint,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (role != null)
                        Text(
                          role,
                          style: const TextStyle(
                            color: AppColors.textOnDarkMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              PopupMenuButton<VoidCallback>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (action) => action(),
                itemBuilder: (context) => [
                  if (onViewListing != null)
                    PopupMenuItem(
                      value: onViewListing!,
                      child: const Text('View Listing'),
                    ),
                  for (final (label, newStatus) in _actions)
                    PopupMenuItem(
                      value: () => onUpdateStatus(newStatus),
                      child: Text(label),
                    ),
                  if (otherParty != null) ...[
                    PopupMenuItem(
                      value: () => showReportSheet(
                        context,
                        target: ReportTarget.user,
                        targetId: otherParty!.id,
                      ),
                      child: const Text('Report user'),
                    ),
                    PopupMenuItem(
                      value: () async {
                        final navigator = Navigator.of(context);
                        final blocked = await confirmAndBlockUser(
                          context,
                          userId: otherParty!.id,
                          userName: otherParty!.name,
                        );
                        if (blocked && navigator.mounted) navigator.pop();
                      },
                      child: Text('Block ${otherParty!.name}'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedListingCard extends StatelessWidget {
  const _PinnedListingCard({required this.listing, required this.onTap});

  final Listing listing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              ListingThumbnail(url: listing.thumbnailUrl, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      listingPriceLabel(listing),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Icon(Icons.verified_user, size: 20, color: AppColors.primary),
            SizedBox(height: 4),
            Text(
              'Chat safely within Shobuj Marketplace',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Keep your conversations here. Do not share personal contact '
              'details such as phone number or email.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickReplyChip extends StatelessWidget {
  const _QuickReplyChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.date});

  final DateTime date;

  String get _label {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    final yesterday = now.subtract(const Duration(days: 1));
    if (_isSameDay(date, yesterday)) return 'Yesterday';
    return DateFormat.yMMMd().format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// A synthesized, not-a-real-message summary of the offer that opened this
/// thread — built entirely from real [SwapOffer] fields (requester, the
/// listing's real price, and live status), not a fabricated message row.
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    this.onReply,
    this.onQuoteTap,
    this.myUserId,
    this.onReact,
  });

  final SwapMessage message;
  final bool isMine;
  final VoidCallback? onReply;
  final VoidCallback? onQuoteTap;
  final int? myUserId;
  final ValueChanged<String>? onReact;

  @override
  Widget build(BuildContext context) {
    if (message.isSystemEvent) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              message.body ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
        ),
      );
    }

    final hasImage = message.hasImages;

    final bubble = Opacity(
      opacity: message.isPending ? 0.75 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: hasImage
            ? const EdgeInsets.all(4)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.replyToId != null)
              Padding(
                padding: hasImage
                    ? const EdgeInsets.fromLTRB(4, 4, 4, 0)
                    : EdgeInsets.zero,
                child: ReplyQuote(
                  reply: message.replyTo,
                  onDarkBubble: isMine,
                  onTap: onQuoteTap,
                ),
              ),
            if (hasImage)
              ChatImageGrid(
                urls: message.imageUrls,
                files: message.localImages,
              ),
            if (message.body != null && message.body!.isNotEmpty)
              Padding(
                padding: hasImage
                    ? const EdgeInsets.fromLTRB(8, 6, 8, 0)
                    : EdgeInsets.zero,
                child: Text(
                  message.body!,
                  style: TextStyle(
                    color: isMine ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            Padding(
              padding: hasImage
                  ? const EdgeInsets.fromLTRB(8, 4, 8, 4)
                  : const EdgeInsets.only(top: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.isPending
                        ? 'Sending…'
                        : timeago.format(message.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isMine ? Colors.white70 : AppColors.textMuted,
                    ),
                  ),
                  if (message.isPending) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.access_time,
                      size: 10,
                      color: isMine ? Colors.white70 : AppColors.textMuted,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final canAct = !message.isPending;

    if (isMine) {
      return SwipeToReply(
        onReply: canAct ? onReply : null,
        child: Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                key: Key('message-bubble-${message.id}'),
                onLongPress: canAct ? () => _showMessageActions(context) : null,
                child: bubble,
              ),
              ReactionChips(
                reactions: message.reactions,
                myUserId: myUserId,
                onTap: canAct ? onReact : null,
              ),
            ],
          ),
        ),
      );
    }

    final sender = message.sender;
    return SwipeToReply(
      onReply: canAct ? onReply : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          GestureDetector(
            onTap: () => openUserProfile(context, sender?.id),
            child: UserAvatar(
              name: sender?.name ?? '?',
              avatarUrl: sender?.avatarUrl,
              radius: 12,
            ),
          ),
          const SizedBox(width: 6),
          // Long-press a message to reply to it, or (from the other person)
          // report it.
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  key: Key('message-bubble-${message.id}'),
                  onLongPress: canAct
                      ? () => _showMessageActions(context)
                      : null,
                  child: bubble,
                ),
                ReactionChips(
                  reactions: message.reactions,
                  myUserId: myUserId,
                  onTap: canAct ? onReact : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReactionPickerRow(
              current: myReaction(message.reactions, myUserId),
              onPick: (emoji) {
                Navigator.of(sheetContext).pop();
                onReact?.call(emoji);
              },
            ),
            ListTile(
              key: const Key('reply-to-message'),
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onReply?.call();
              },
            ),
            if (!isMine)
              ListTile(
                key: const Key('report-message'),
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report message'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  showReportSheet(
                    context,
                    target: ReportTarget.message,
                    targetId: message.id,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
