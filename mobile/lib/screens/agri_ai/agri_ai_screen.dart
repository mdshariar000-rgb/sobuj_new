import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/ai_providers.dart';
import '../../providers/subscription_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import 'agri_ai_paywall_screen.dart';
import 'widgets/ai_consent_view.dart';
import 'widgets/ai_history_sheet.dart';
import 'widgets/ai_message_bubble.dart';

/// The Agri-AI tab: a chat interface with FloraAI, the Gemini-backed
/// plant-care assistant — text questions and/or a leaf photo for diagnosis.
class AgriAiScreen extends ConsumerStatefulWidget {
  const AgriAiScreen({super.key});

  @override
  ConsumerState<AgriAiScreen> createState() => _AgriAiScreenState();
}

class _AgriAiScreenState extends ConsumerState<AgriAiScreen> {
  final _bodyController = TextEditingController();
  final _scrollController = ScrollController();
  File? _photo;
  String? _errorMessage;

  @override
  void dispose() {
    _bodyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// [animated] is false when a whole past conversation is loaded at once
  /// (opening it from history) — like WhatsApp, it should already be
  /// sitting at the latest message with no visible scroll animation, not
  /// visibly scroll down from the top. True for a message actually being
  /// sent/replied to during this session.
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

  Future<void> _pickPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) setState(() => _photo = File(picked.path));
  }

  Future<void> _send() async {
    final body = _bodyController.text.trim();
    if (body.isEmpty && _photo == null) return;

    final photo = _photo;
    setState(() {
      _errorMessage = null;
      _photo = null;
    });
    _bodyController.clear();

    try {
      await ref
          .read(aiChatProvider.notifier)
          .sendMessage(body: body.isEmpty ? null : body, photo: photo);
      _scrollToBottom();
    } on ApiException catch (e) {
      if (_bodyController.text.isEmpty) _bodyController.text = body;
      setState(() => _errorMessage = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(subscriptionStatusProvider);

    // No free tier at all — the whole feature is behind Agri-AI Premium.
    // While the status is loading, show a spinner rather than flashing the
    // paywall or the chat UI first; on error, fail closed to the paywall
    // rather than silently granting access.
    return subscriptionAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => const AgriAiPaywallScreen(),
      data: (subscription) {
        if (!subscription.hasAccess) return const AgriAiPaywallScreen();

        // Chatting sends the user's messages/photos to Google's Gemini API,
        // so it needs their explicit consent first. Fails closed (shows the
        // consent screen) if the stored answer can't be read.
        return ref
            .watch(aiConsentProvider)
            .when(
              loading: () => const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const AiConsentView(),
              data: (consented) =>
                  consented ? _buildChat(context) : const AiConsentView(),
            );
      },
    );
  }

  Widget _buildChat(BuildContext context) {
    final chatState = ref.watch(aiChatProvider);

    ref.listen(aiChatProvider, (previous, next) {
      if (next.messages.length != (previous?.messages.length ?? 0)) {
        // isLoading is only ever true while switching to a past conversation
        // from history — that's a whole conversation appearing at once, not
        // a message actually being sent live.
        final isBulkLoad = previous?.isLoading == true && !next.isLoading;
        _scrollToBottom(animated: !isBulkLoad);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agri-AI Assistant'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New chat',
            onPressed: () => ref.read(aiChatProvider.notifier).startNewChat(),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () {
              ref.invalidate(aiConversationsProvider);
              showAiHistorySheet(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
                ? const _EmptyChatView()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount:
                        chatState.messages.length +
                        (chatState.isSending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= chatState.messages.length) {
                        return const _TypingIndicator();
                      }
                      final message = chatState.messages[index];
                      return AiMessageBubble(
                        key: ValueKey(message.id),
                        message: message,
                      );
                    },
                  ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppColors.error, fontSize: 13),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_photo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, left: 4),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _photo!,
                              height: 80,
                              width: 80,
                              fit: BoxFit.cover,
                            ),
                          ),
                          IconButton(
                            icon: const CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.black54,
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                            onPressed: () => setState(() => _photo = null),
                          ),
                        ],
                      ),
                    ),
                  _Composer(
                    controller: _bodyController,
                    isSending: chatState.isSending,
                    onAttach: _pickPhoto,
                    onSend: _send,
                    onFocusGained: _scrollToBottom,
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

class _EmptyChatView extends StatelessWidget {
  const _EmptyChatView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.spa_outlined,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Ask FloraAI anything',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Plant care questions, pest and disease diagnosis — attach a '
              'leaf photo for a closer look.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The composer bar — a floating pill (no harsh divider above it) with an
/// attach button, an auto-growing text field, and a send button that
/// animates in once there's something to send.
class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onAttach,
    required this.onSend,
    required this.onFocusGained,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  /// Called when the composer gains focus (the keyboard is opening) — a
  /// plain ListView doesn't automatically follow the shrinking viewport, so
  /// without re-scrolling here the latest messages end up hidden behind the
  /// keyboard the moment you tap in to type.
  final VoidCallback onFocusGained;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) widget.onFocusGained();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final hasContent = widget.controller.text.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.image_outlined, color: AppColors.textMuted),
            tooltip: 'Attach a leaf photo',
            onPressed: widget.isSending ? null : widget.onAttach,
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ask about a plant, or attach a photo…',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              onSubmitted: (_) => widget.onSend(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: widget.isSending
                  ? Container(
                      key: const ValueKey('sending'),
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.buttonMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton.filled(
                      key: const ValueKey('send'),
                      onPressed: hasContent ? widget.onSend : null,
                      style: IconButton.styleFrom(
                        backgroundColor: hasContent
                            ? AppColors.primary
                            : AppColors.buttonMuted,
                        foregroundColor: hasContent
                            ? Colors.white
                            : AppColors.textMuted,
                      ),
                      icon: const Icon(Icons.arrow_upward, size: 20),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A "FloraAI is thinking" row — matches the assistant's avatar-led message
/// layout with three softly pulsing dots instead of a bare spinner.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 24, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: const BoxDecoration(
              color: AppColors.mint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 15,
              color: AppColors.forestDark,
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_controller.value - i * 0.2) % 1.0;
                    final opacity = 0.3 + 0.7 * (0.5 - (t - 0.5).abs()) * 2;
                    return Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: Opacity(
                        opacity: opacity.clamp(0.3, 1.0),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: AppColors.textMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
