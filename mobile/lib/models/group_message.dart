import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_user.dart';
import 'message_images.dart';
import 'message_reaction.dart';
import 'message_reply.dart';

/// Mirrors GroupMessageResource on the backend — a single message within a
/// group's real-time chat.
@immutable
class GroupMessage {
  const GroupMessage({
    required this.id,
    required this.groupId,
    this.body,
    this.imageUrls = const [],
    this.sender,
    this.senderIsAdmin,
    required this.createdAt,
    this.isPending = false,
    this.localImages = const [],
    this.replyToId,
    this.replyTo,
    this.reactions = const [],
  });

  final int id;
  final int groupId;

  /// Null for an image-only message with no caption.
  final String? body;

  /// Every uploaded photo on this message, in the order sent — empty for a
  /// text-only message.
  final List<String> imageUrls;

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

  /// Set only on a pending message with attached photos, before they've
  /// been uploaded — lets the bubble show the picked photos immediately
  /// instead of waiting for server-hosted [imageUrls].
  final List<File> localImages;

  bool get hasImages => localImages.isNotEmpty || imageUrls.isNotEmpty;

  /// Set when this message is a reply. [replyTo] is the quote to show; it's
  /// null (with [replyToId] still set) when the quoted message was deleted
  /// or is from someone blocked.
  final int? replyToId;
  final MessageReply? replyTo;

  /// Emoji reactions, grouped by emoji — empty when there are none.
  final List<MessageReaction> reactions;

  /// This message with its reactions replaced — everything else unchanged.
  GroupMessage withReactions(List<MessageReaction> reactions) {
    return GroupMessage(
      id: id,
      groupId: groupId,
      body: body,
      imageUrls: imageUrls,
      sender: sender,
      senderIsAdmin: senderIsAdmin,
      createdAt: createdAt,
      isPending: isPending,
      localImages: localImages,
      replyToId: replyToId,
      replyTo: replyTo,
      reactions: reactions,
    );
  }

  factory GroupMessage.fromJson(Map<String, dynamic> json) {
    return GroupMessage(
      id: json['id'] as int,
      groupId: json['group_id'] as int,
      body: json['body'] as String?,
      imageUrls: parseMessageImageUrls(json),
      replyToId: parseOptionalId(json['reply_to_id']),
      replyTo: MessageReply.tryFromJson(json['reply_to']),
      reactions: MessageReaction.listFromJson(json['reactions']),
      sender: json['sender'] != null
          ? AppUser.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      senderIsAdmin: json['sender_is_admin'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
