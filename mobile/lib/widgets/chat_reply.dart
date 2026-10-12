import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/message_reply.dart';
import '../theme/app_colors.dart';
import 'image_decode.dart';

/// Swipe a chat message to the right to reply to it: the bubble follows the
/// finger (up to [_maxDrag]), a reply icon fades in behind it, and letting
/// go past [_trigger] calls [onReply]. Null [onReply] disables the gesture.
class SwipeToReply extends StatefulWidget {
  const SwipeToReply({super.key, required this.child, this.onReply});

  final Widget child;
  final VoidCallback? onReply;

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  static const _maxDrag = 72.0;
  static const _trigger = 56.0;

  late final AnimationController _settle =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 180),
      )..addListener(
        () => setState(() => _offset = _settleFrom * (1 - _settle.value)),
      );

  double _offset = 0;
  double _settleFrom = 0;
  bool _armed = false;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _onUpdate(DragUpdateDetails details) {
    setState(() {
      _offset = (_offset + details.delta.dx).clamp(0, _maxDrag);
    });
    final armed = _offset >= _trigger;
    if (armed && !_armed) HapticFeedback.selectionClick();
    _armed = armed;
  }

  void _onEnd(DragEndDetails _) {
    if (_armed) widget.onReply?.call();
    _armed = false;
    _settleFrom = _offset;
    _settle.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onReply == null) return widget.child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Opacity(
            opacity: (_offset / _trigger).clamp(0, 1),
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.reply, color: AppColors.textMuted),
            ),
          ),
          Transform.translate(offset: Offset(_offset, 0), child: widget.child),
        ],
      ),
    );
  }
}

/// The quoted message shown at the top of a reply's bubble. Tapping it
/// jumps to the original ([onTap]).
class ReplyQuote extends StatelessWidget {
  const ReplyQuote({
    super.key,
    required this.reply,
    required this.onDarkBubble,
    this.onTap,
  });

  /// Null when the quoted message was deleted or is from someone blocked.
  final MessageReply? reply;
  final bool onDarkBubble;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reply = this.reply;
    final accent = onDarkBubble ? Colors.white : AppColors.primary;
    final textColor = onDarkBubble ? Colors.white70 : AppColors.textMuted;

    return GestureDetector(
      onTap: reply == null ? null : onTap,
      child: Container(
        key: const Key('reply-quote'),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: onDarkBubble
              ? Colors.white.withValues(alpha: 0.15)
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: reply == null
            ? Text(
                'Original message unavailable',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: textColor,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          reply.senderName ?? 'Unknown grower',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        Text(
                          reply.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: textColor),
                        ),
                      ],
                    ),
                  ),
                  if (reply.imageUrl != null) ...[
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: reply.imageUrl!,
                        width: 36,
                        height: 36,
                        memCacheWidth: decodeWidthFor(context, 36),
                        fit: BoxFit.cover,
                        errorWidget: (context, _, _) =>
                            const SizedBox(width: 36, height: 36),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Shown above the composer while replying: who and what is being answered,
/// with ✕ to cancel.
class ReplyComposerBar extends StatelessWidget {
  const ReplyComposerBar({
    super.key,
    required this.reply,
    required this.onCancel,
  });

  final MessageReply reply;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('reply-composer-bar'),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${reply.senderName ?? 'Unknown grower'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  reply.summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('cancel-reply'),
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Cancel reply',
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}
