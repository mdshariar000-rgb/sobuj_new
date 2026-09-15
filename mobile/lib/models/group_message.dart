import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_user.dart';

/// Mirrors GroupMessageResource on the backend — a single message within a
/// group's real-time chat.
@immutable
class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    this.body,
    this.imageUrl,
    this.sender,
    this.senderIsAdmin,
    required this.createdAt,
    this.isPending = false,
    this.localImage,
  });

  final int id;
  final int groupId;

  /// Null for an image-only message with no caption.
  final String? body;

  /// Set when this message carries a real uploaded photo.
  final String? imageUrl;

  /// Null for a message whose original sender has since deleted their
  /// account.
  final AppUser? sender;

  /// The sender's real group_members.role at send time — see
  /// GroupMessageResource::sender_is_admin on the backend.
  final bool? senderIsAdmin;

  final DateTime createdAt;

  /// True only for a locally-created optimistic echo of the user's own
  /// message, shown instantly while the real request is still in flight —
  /// never true for anything that came from the backend.
  final bool isPending;

  /// Set only on a pending message with an attached photo, before it has
  /// been uploaded — lets the bubble show the picked photo immediately
  /// instead of waiting for a server-hosted [imageUrl].
  final File? localImage;

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    return GroupMessage(
      id: json['id'] as int,
      groupId: json['group_id'] as int,
      body: json['body'] as String?,
      imageUrl: json['image_url'] as String?,
      sender: json['sender'] != null
          ? AppUser.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      senderIsAdmin: json['sender_is_admin'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
