import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_user.dart';
import 'message_images.dart';
import 'message_reaction.dart';
import 'message_reply.dart';

/// Mirrors MessageResource on the backend — a single message within a
/// [SwapOffer]'s thread. Named "SwapMessage" (not "Message") to avoid any
/// ambiguity with a future direct-messaging feature.
@immutable
class SwapMessage {
  const SwapMessage({
    required this.id,
    required this.swapOfferId,
    required this.isSystemEvent,
    this.body,
    this.imageUrls = const [],
    this.sender,
    required this.createdAt,
    this.isPending = false,
    this.localImages = const [],
    this.replyToId,
    this.replyTo,
    this.reactions = const [],
  });

  final int id;
  final int swapOfferId;

  /// True for an automatic "X made an offer" / "X accepted" line rather than
  /// something a person actually typed.
  final bool isSystemEvent;

  /// Null for an image-only message with no caption.
  final String? body;

  /// Every uploaded photo on this message, in the order sent — empty for a
  /// text-only message.
  final List<String> imageUrls;

  /// Null for a system-event message.
  final AppUser? sender;
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
  SwapMessage withReactions(List<MessageReaction> reactions) {
    return SwapMessage(
      id: id,
      swapOfferId: swapOfferId,
      isSystemEvent: isSystemEvent,
      body: body,
      imageUrls: imageUrls,
      sender: sender,
      createdAt: createdAt,
      isPending: isPending,
      localImages: localImages,
      replyToId: replyToId,
      replyTo: replyTo,
      reactions: reactions,
    );
  }

  factory SwapMessage.fromJson(Map<String, dynamic> json) {
    return SwapMessage(
      id: json['id'] as int,
      swapOfferId: json['swap_offer_id'] as int,
      isSystemEvent: json['message_type'] == 'system_event',
      body: json['body'] as String?,
      imageUrls: parseMessageImageUrls(json),
      replyToId: parseOptionalId(json['reply_to_id']),
      replyTo: MessageReply.tryFromJson(json['reply_to']),
      reactions: MessageReaction.listFromJson(json['reactions']),
      sender: json['sender'] != null
          ? AppUser.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
