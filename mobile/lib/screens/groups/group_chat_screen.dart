import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/group.dart';
import '../../models/group_message.dart';
import '../../models/message_reaction.dart';
import '../../models/message_reply.dart';
import '../../models/report.dart';
import '../../providers/auth_providers.dart';
import '../../providers/group_providers.dart';
import '../../services/api_exception.dart';
import '../../services/group_realtime_channel.dart';
import '../../theme/app_colors.dart';
import '../../widgets/chat_image_grid.dart';
import '../../widgets/chat_reactions.dart';
import '../../widgets/chat_reply.dart';
import '../../widgets/pending_images_strip.dart';
import '../../widgets/safety_actions.dart';
import '../../widgets/user_avatar.dart';
import '../discovery/seller_profile_screen.dart';
import '../../widgets/shimmer.dart';

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// A group's real-time chat — real GET/POST against GroupMessageController,
/// with live delivery over a per-group Reverb WebSocket channel (see
/// [GroupRealtimeChannel]), mirroring SwapOfferThreadScreen's approach for
/// the marketplace's 1:1 chat. No online-presence indicator, read receipts,
/// or AI-suggested replies — none of those exist on the backend.
class GroupChatScreen extends ConsumerStatefulWidget {
  const GroupChatScreen({super.key, required this.group});

  final Group group;

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
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
  int _lastMessageCount = 0;
  GroupRealtimeChannel? _realtime;

  @override
  void initState() {
    super.initState();
    final channel = ref.read(groupRealtimeChannelProvider(widget.group.id))
      ..onMessage = (message) {
        ref
            .read(groupMessagesProvider(widget.group.id).notifier)
            .receiveMessage(message);
      }
      ..onReactions = (messageId, reactions) {
        ref
            .read(groupMessagesProvider(widget.group.id).notifier)
            .applyReactions(messageId, reactions);
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
  /// a chat used to land wherever the list happened to start rather than at
  /// the real latest message.
  /// [animated] is false for the chat's initial open — like WhatsApp, it
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
          .read(groupMessagesProvider(widget.group.id).notifier)
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

  Future<void> _react(int messageId, String emoji) async {
    try {
      await ref
          .read(groupMessagesProvider(widget.group.id).notifier)
          .react(messageId, emoji);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _startReply(GroupMessage message) {
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
  void _scrollToMessage(int messageId, List<GroupMessage> messages) {
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
  Future<void> _addImages(ImageSource source) async {
    final remaining = maxChatImages - _pendingImages.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can send up to $maxChatImages photos at a time.'),
        ),
      );
      return;
    }

    final List<File> picked;
    if (source == ImageSource.gallery) {
      picked = await pickChatImagesFromGallery(remaining: remaining);
    } else {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      picked = photo == null ? const [] : [File(photo.path)];
    }
    if (picked.isEmpty || !mounted) return;
    setState(() => _pendingImages.addAll(picked));
  }

  Future<void> _sendQuickReply(String text) async {
    setState(() => _isSending = true);
    try {
      await ref
          .read(groupMessagesProvider(widget.group.id).notifier)
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

  Future<void> _unpin() async {
    try {
      await ref
          .read(groupDetailProvider(widget.group).notifier)
          .setPinnedMessage('');
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
    final messagesAsync = ref.watch(groupMessagesProvider(widget.group.id));
    final groupAsync = ref.watch(groupDetailProvider(widget.group));
    final group = groupAsync.valueOrNull ?? widget.group;
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;

    ref.listen(groupMessagesProvider(widget.group.id), (previous, next) {
      final count = next.valueOrNull?.length ?? 0;
      if (count > _lastMessageCount) {
        // No prior data means this is the chat's first-ever render of real
        // messages (opening it), not a message arriving mid-session.
        final isInitialLoad = previous?.valueOrNull == null;
        _lastMessageCount = count;
        _scrollToBottom(animated: !isInitialLoad);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _ChatHeader(group: group),
          if (group.pinnedMessage != null)
            _PinnedBanner(
              group: group,
              canUnpin: group.myRoleIsAdmin,
              onUnpin: _unpin,
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const ShimmerChat(),
              error: (error, _) => Center(child: Text('$error')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet — say hello!',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
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
                    final isMine = message.sender?.id == currentUserId;
                    final showSenderName =
                        !isMine &&
                        (previous == null ||
                            previous.sender?.id != message.sender?.id);

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
                            isMine: isMine,
                            showSenderName: showSenderName,
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
          // Static canned replies — always the same three options, not
          // AI-personalized (there's no per-message suggestion model). Each
          // just sends its literal text as a real chat message.
          Container(
            width: double.infinity,
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_outlined,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                const Text(
                  'Quick:',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final reply in const [
                          '\u{1F44D}',
                          '\u{1F33F} Great advice!',
                          '\u{1F338} Looks healthy!',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: OutlinedButton(
                              onPressed: _isSending
                                  ? null
                                  : () => _sendQuickReply(reply),
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                side: const BorderSide(color: AppColors.border),
                              ),
                              child: Text(
                                reply,
                                style: const TextStyle(fontSize: 12),
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
          if (_replyingTo != null)
            ReplyComposerBar(
              reply: _replyingTo!,
              onCancel: () => setState(() => _replyingTo = null),
            ),
          PendingImagesStrip(
            files: _pendingImages,
            onRemove: (index) => setState(() => _pendingImages.removeAt(index)),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isSending
                        ? null
                        : () => _addImages(ImageSource.gallery),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    tooltip: 'Attach photos',
                  ),
                  IconButton(
                    onPressed: _isSending
                        ? null
                        : () => _addImages(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    tooltip: 'Take a photo',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _composerFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Message ${group.name}...',
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
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.forestPanel,
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: AppColors.forestPanel,
                      shape: BoxShape.circle,
                    ),
                    child: UserAvatar(
                      name: group.name,
                      avatarUrl: group.avatarUrl ?? group.coverImageUrl,
                      radius: 18,
                      fallbackColor: AppColors.mint.withValues(alpha: 0.18),
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.mint,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(
                          BorderSide(color: AppColors.forestPanel, width: 2),
                        ),
                      ),
                      child: const Icon(
                        Icons.eco,
                        size: 10,
                        color: AppColors.forestDark,
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
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (group.membersCount != null)
                      Text(
                        '${group.membersCount} '
                        '${group.membersCount == 1 ? 'member' : 'members'}',
                        style: const TextStyle(
                          color: AppColors.textOnDarkMuted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.info_outline, color: Colors.white),
                tooltip: 'Group info',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedBanner extends StatelessWidget {
  const _PinnedBanner({
    required this.group,
    required this.canUnpin,
    required this.onUnpin,
  });

  final Group group;
  final bool canUnpin;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) {
    final pinnedByName = group.pinnedBy?.name;
    return InkWell(
      onTap: () => openUserProfile(context, group.pinnedBy?.id),
      child: Container(
        width: double.infinity,
        color: AppColors.surfaceMuted,
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.push_pin, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textDark,
                  ),
                  children: [
                    if (pinnedByName != null)
                      TextSpan(
                        text: 'Pinned by $pinnedByName: ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    TextSpan(text: group.pinnedMessage),
                  ],
                ),
              ),
            ),
            if (canUnpin)
              InkWell(
                onTap: onUnpin,
                child: const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
          ],
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
            _label.toUpperCase(),
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.showSenderName,
    this.onReply,
    this.onQuoteTap,
    this.myUserId,
    this.onReact,
  });

  final GroupMessage message;
  final bool isMine;
  final bool showSenderName;
  final VoidCallback? onReply;
  final VoidCallback? onQuoteTap;
  final int? myUserId;
  final ValueChanged<String>? onReact;

  @override
  Widget build(BuildContext context) {
    final sender = message.sender;
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
          color: isMine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isMine ? null : Border.all(color: AppColors.surfaceMuted),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMine && showSenderName)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  hasImage ? 8 : 0,
                  hasImage ? 6 : 0,
                  0,
                  4,
                ),
                child: GestureDetector(
                  onTap: () => openUserProfile(context, sender?.id),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sender?.name ?? 'Unknown grower',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      if (message.senderIsAdmin ?? false) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E3E0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.label,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
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
          // Long-press a message from another member to report it or block them.
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
    final sender = message.sender;

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
                    target: ReportTarget.groupMessage,
                    targetId: message.id,
                  );
                },
              ),
            if (!isMine && sender != null)
              ListTile(
                key: const Key('block-sender'),
                leading: const Icon(Icons.block, color: AppColors.error),
                title: Text(
                  'Block ${sender.name}',
                  style: const TextStyle(color: AppColors.error),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  confirmAndBlockUser(
                    context,
                    userId: sender.id,
                    userName: sender.name,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
