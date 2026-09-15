import 'package:flutter/foundation.dart';

import 'ai_message.dart';

/// Mirrors AiConversationResource on the backend.
@immutable
class AiConversation {
  const AiConversation({
    required this.id,
    this.title,
    this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String? title;

  /// Only present when this came from show()/sendMessage() — the
  /// conversation list (index()) doesn't eager-load messages.
  final List<AiMessage>? messages;

  final DateTime createdAt;
  final DateTime updatedAt;

  factory AiConversation.fromJson(Map<String, dynamic> json) {
    return AiConversation(
      id: json['id'] as int,
      title: json['title'] as String?,
      messages: json['messages'] != null
          ? (json['messages'] as List<dynamic>)
                .map((item) => AiMessage.fromJson(item as Map<String, dynamic>))
                .toList(growable: false)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
