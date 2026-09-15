import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../models/group.dart';
import '../../models/group_message.dart';
import '../../providers/auth_providers.dart';
import '../../providers/group_providers.dart';
import '../../services/api_exception.dart';
import '../../services/group_realtime_channel.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_avatar.dart';

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
    if (body.isEmpty) return;

    _controller.clear();
    setState(() => _isSending = true);
    try {
      await ref
          .read(groupMessagesProvider(widget.group.id).notifier)
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

  Future<void> _sendImage(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isSending = true);
    try {
      await ref
          .read(groupMessagesProvider(widget.group.id).notifier)
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
              loading: () => const Center(child: CircularProgressIndicator()),
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
                    final previous = index - 1 >= 0 ? messages[index - 1] : null;
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
                        if (showDateDivider) _DateDivider(date: message.createdAt),
                        _MessageBubble(
                          message: message,
                          isMine: isMine,
                          showSenderName: showSenderName,
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
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isSending
                        ? null
                        : () => _sendImage(ImageSource.gallery),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    tooltip: 'Attach a photo',
                  ),
                  IconButton(
                    onPressed: _isSending
                        ? null
                        : () => _sendImage(ImageSource.camera),
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
                        '${group.membersCount} members',
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
    return Container(
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
                style: const TextStyle(fontSize: 12.5, color: AppColors.textDark),
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
                child: Icon(Icons.close, size: 16, color: AppColors.textMuted),
              ),
            ),
        ],
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
  });

  final GroupMessage message;
  final bool isMine;
  final bool showSenderName;

  @override
  Widget build(BuildContext context) {
    final sender = message.sender;
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        UserAvatar(
          name: sender?.name ?? '?',
          avatarUrl: sender?.avatarUrl,
          radius: 12,
        ),
        const SizedBox(width: 6),
        Flexible(child: bubble),
      ],
    );
  }
}
