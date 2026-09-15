import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/app_user.dart';
import '../../models/listing.dart';
import '../../models/swap_message.dart';
import '../../models/swap_offer.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/discovery_providers.dart';
import '../../services/api_exception.dart';
import '../../services/swap_offer_realtime_channel.dart';
import '../../theme/app_colors.dart';
import 'listing_detail_screen.dart';
import 'widgets/listing_thumbnail.dart';

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
    if (body.isEmpty) return;

    _controller.clear();
    setState(() => _isSending = true);
    try {
      await ref
          .read(swapOfferMessagesProvider(_swapOffer.id).notifier)
          .sendMessage(body: body);
    } on ApiException catch (e) {
      if (mounted) {
        if (_controller.text.isEmpty) _controller.text = body;
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

  Future<void> _sendImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isSending = true);
    try {
      await ref
          .read(swapOfferMessagesProvider(_swapOffer.id).notifier)
          .sendMessage(image: File(picked.path));
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

  Future<void> _updateStatus(SwapOfferStatus status) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final updated = await apiClient.updateSwapOfferStatus(
        _swapOffer.id,
        status,
      );
      if (mounted) setState(() => _swapOffer = updated);
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
            if (listing != null)
              _PinnedListingCard(
                listing: listing,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ListingDetailScreen(listing: listing),
                  ),
                ),
              ),
            const _SafetyNotice(),
            Expanded(
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('$error')),
                data: (messages) {
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _OfferSummaryBubble(swapOffer: _swapOffer);
                      }

                      final message = messages[index - 1];
                      final previous = index - 2 >= 0
                          ? messages[index - 2]
                          : null;
                      final showDateDivider =
                          previous == null ||
                          !_isSameDay(previous.createdAt, message.createdAt);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showDateDivider)
                            _DateDivider(date: message.createdAt),
                          _MessageBubble(
                            message: message,
                            isMine: message.sender?.id == currentUserId,
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
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _isSending ? null : _sendImage,
                      icon: const Icon(Icons.add_circle_outline),
                      tooltip: 'Send a photo',
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
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.mint.withValues(alpha: 0.18),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.mint,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: AppColors.forestPanel,
        child: Row(
          children: [
            ListingThumbnail(url: listing.thumbnailUrl, size: 44),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                listing.transactionType.label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.forestDark,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.price != null
                        ? NumberFormat.simpleCurrency().format(listing.price)
                        : listing.transactionType.label,
                    style: const TextStyle(
                      color: AppColors.mint,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View',
                  style: TextStyle(color: AppColors.mint, fontSize: 12),
                ),
                Icon(Icons.chevron_right, color: AppColors.mint, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyNotice extends StatelessWidget {
  const _SafetyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, size: 16, color: AppColors.textMuted),
            SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Safe Grower Exchange: ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text:
                          'inspect live plants and seeds during daytime meetups.',
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 11.5, color: AppColors.textDark),
              ),
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
class _OfferSummaryBubble extends StatelessWidget {
  const _OfferSummaryBubble({required this.swapOffer});

  final SwapOffer swapOffer;

  @override
  Widget build(BuildContext context) {
    final listing = swapOffer.listing;
    final requesterName = swapOffer.requester?.name ?? 'Someone';
    final text = listing?.price != null
        ? '$requesterName offered '
              '${NumberFormat.simpleCurrency().format(listing!.price)} '
              '(Listing Price)'
        : '$requesterName proposed a trade'
              '${listing != null ? ' for "${listing.title}"' : ''}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceMuted),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.mint,
            child: Icon(
              Icons.handshake_outlined,
              size: 16,
              color: AppColors.forestDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          _OfferStatusPill(status: swapOffer.status),
        ],
      ),
    );
  }
}

class _OfferStatusPill extends StatelessWidget {
  const _OfferStatusPill({required this.status});

  final SwapOfferStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.isOpen
            ? AppColors.mint.withValues(alpha: 0.4)
            : AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final SwapMessage message;
  final bool isMine;

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

    final hasImage = message.localImage != null || message.imageUrl != null;

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
            if (message.localImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  message.localImage!,
                  width: 160,
                  height: 160,
                  fit: BoxFit.cover,
                ),
              )
            else if (message.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  message.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, _, _) => const SizedBox(
                    width: 160,
                    height: 160,
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
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

    if (isMine) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }

    final sender = message.sender;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppColors.surfaceMuted,
          child: Text(
            (sender?.name.isNotEmpty ?? false)
                ? sender!.name[0].toUpperCase()
                : '?',
            style: const TextStyle(fontSize: 10, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: bubble),
      ],
    );
  }
}
