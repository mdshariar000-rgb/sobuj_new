import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../models/ai_message.dart';
import '../../../models/ai_message_role.dart';
import '../../../theme/app_colors.dart';
import 'simple_markdown_text.dart';

/// A single chat turn. Assistant replies use an avatar-led, borderless
/// layout (matching modern AI chat apps — full-width text rather than a
/// cramped bubble) with light markdown rendering; the user's own messages
/// stay a right-aligned bubble. Plays a brief fade/rise-in once when it
/// first appears, keyed by message id so already-shown messages don't
/// replay it on every rebuild.
class AiMessageBubble extends StatefulWidget {
  const AiMessageBubble({super.key, required this.message});

  final AiMessage message;

  @override
  State<AiMessageBubble> createState() => _AiMessageBubbleState();
}

class _AiMessageBubbleState extends State<AiMessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.role == AiMessageRole.user;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: isUser ? _UserBubble(message: widget.message) : _AssistantTurn(message: widget.message),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Opacity(
        opacity: message.isPending ? 0.75 : 1,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          margin: const EdgeInsets.fromLTRB(48, 6, 16, 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.localImage != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    message.localImage!,
                    width: 200,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
                if (message.body != null && message.body!.isNotEmpty)
                  const SizedBox(height: 8),
              ] else if (message.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: message.imageUrl!,
                    width: 200,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
                if (message.body != null && message.body!.isNotEmpty)
                  const SizedBox(height: 8),
              ],
              if (message.body != null && message.body!.isNotEmpty)
                Text(
                  message.body!,
                  style: const TextStyle(color: Colors.white, height: 1.35),
                ),
              if (message.isPending)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(
                    Icons.access_time,
                    size: 11,
                    color: Colors.white70,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantTurn extends StatelessWidget {
  const _AssistantTurn({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 24, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FloraAvatar(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (message.imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CachedNetworkImage(
                      imageUrl: message.imageUrl!,
                      width: 200,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (message.body != null && message.body!.isNotEmpty)
                    const SizedBox(height: 8),
                ],
                if (message.body != null && message.body!.isNotEmpty)
                  SimpleMarkdownText(
                    text: message.body!,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      height: 1.45,
                      fontSize: 15,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FloraAvatar extends StatelessWidget {
  const _FloraAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.only(top: 2),
      decoration: const BoxDecoration(color: AppColors.mint, shape: BoxShape.circle),
      child: const Icon(Icons.auto_awesome, size: 15, color: AppColors.forestDark),
    );
  }
}
