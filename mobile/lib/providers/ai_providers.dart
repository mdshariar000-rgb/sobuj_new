import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_conversation.dart';
import '../models/ai_message.dart';
import '../models/ai_message_role.dart';
import '../services/api_client.dart';
import 'core_providers.dart';

/// Past conversation history — simple one-shot fetch (no create/delete
/// mutation needed here, unlike Home Feed/Groups), matching Discovery's
/// nearbyListingsProvider pattern. Re-fetch via ref.invalidate/refresh.
final aiConversationsProvider =
    FutureProvider.autoDispose<List<AiConversation>>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.aiConversations();
      return response.data;
    });

@immutable
class AiChatState {
  const AiChatState({
    this.conversation,
    required this.isSending,
    required this.isLoading,
    this.pendingMessage,
  });

  /// Null means a fresh, not-yet-started chat.
  final AiConversation? conversation;

  final bool isSending;

  /// True only while switching to an existing conversation from history.
  final bool isLoading;

  /// The user's own message, shown instantly while the round trip to
  /// Gemini is still in flight — see [AiChatNotifier.sendMessage].
  final AiMessage? pendingMessage;

  List<AiMessage> get messages => [
    ...conversation?.messages ?? const [],
    ?pendingMessage,
  ];

  AiChatState copyWith({
    AiConversation? conversation,
    bool clearConversation = false,
    bool? isSending,
    bool? isLoading,
    AiMessage? pendingMessage,
    bool clearPendingMessage = false,
  }) {
    return AiChatState(
      conversation: clearConversation
          ? null
          : (conversation ?? this.conversation),
      isSending: isSending ?? this.isSending,
      isLoading: isLoading ?? this.isLoading,
      pendingMessage: clearPendingMessage
          ? null
          : (pendingMessage ?? this.pendingMessage),
    );
  }
}

/// The single active chat thread with FloraAI. Starts empty; sending a
/// message either starts a new conversation or continues the current one —
/// the backend always returns the full conversation (including the new
/// user+assistant pair), so state is simply replaced wholesale each time.
class AiChatNotifier extends StateNotifier<AiChatState> {
  AiChatNotifier(this._apiClient)
    : super(const AiChatState(isSending: false, isLoading: false));

  final ApiClient _apiClient;
  int _nextTempId = -1;

  /// Shows the user's own message immediately as a pending bubble (waiting
  /// for the full Gemini round trip otherwise made every send feel stalled),
  /// then replaces it with the real conversation once the reply arrives —
  /// or clears it and rethrows on failure. Throws [ApiException] on failure
  /// — the calling screen handles it.
  Future<void> sendMessage({String? body, File? photo}) async {
    final optimisticUser = AiMessage(
      id: _nextTempId--,
      conversationId: state.conversation?.id ?? 0,
      role: AiMessageRole.user,
      body: body,
      createdAt: DateTime.now(),
      isPending: true,
      localImage: photo,
    );
    state = state.copyWith(isSending: true, pendingMessage: optimisticUser);
    try {
      final conversation = await _apiClient.sendAiMessage(
        conversationId: state.conversation?.id,
        body: body,
        photo: photo,
      );
      state = state.copyWith(
        conversation: conversation,
        isSending: false,
        clearPendingMessage: true,
      );
    } catch (_) {
      state = state.copyWith(isSending: false, clearPendingMessage: true);
      rethrow;
    }
  }

  void startNewChat() {
    state = const AiChatState(isSending: false, isLoading: false);
  }

  Future<void> openConversation(int conversationId) async {
    state = state.copyWith(isLoading: true, clearConversation: true);
    try {
      final conversation = await _apiClient.aiConversation(conversationId);
      state = state.copyWith(conversation: conversation, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
}

final aiChatProvider =
    StateNotifierProvider.autoDispose<AiChatNotifier, AiChatState>(
      (ref) => AiChatNotifier(ref.watch(apiClientProvider)),
    );
