import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ai_message_role.dart';

/// Mirrors AiMessageResource on the backend.
@immutable
class AiMessage {
  const AiMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    this.body,
    this.imageUrl,
    required this.createdAt,
    this.isPending = false,
    this.localImage,
  });

  final int id;
  final int conversationId;
  final AiMessageRole role;
  final String? body;
  final String? imageUrl;
  final DateTime createdAt;

  /// True only for a locally-created optimistic echo of the user's own
  /// message, shown instantly while the real request is still in flight —
  /// never true for anything that came from the backend.
  final bool isPending;

  /// Set only on a pending message with an attached photo, before it has
  /// been uploaded — lets the bubble show the picked photo immediately
  /// instead of waiting for a server-hosted [imageUrl].
  final File? localImage;

  factory AiMessage.fromJson(Map<String, dynamic> json) {
    return AiMessage(
      id: json['id'] as int,
      conversationId: json['conversation_id'] as int,
      role: AiMessageRole.fromValue(json['role'] as String),
      body: json['body'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
