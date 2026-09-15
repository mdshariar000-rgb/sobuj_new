import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_user.dart';

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
    this.imageUrl,
    this.sender,
    required this.createdAt,
    this.isPending = false,
    this.localImage,
  });

  final int id;
  final int swapOfferId;

  /// True for an automatic "X made an offer" / "X accepted" line rather than
  /// something a person actually typed.
  final bool isSystemEvent;

  /// Null for an image-only message with no caption.
  final String? body;

  /// Set when this message carries a real uploaded photo.
  final String? imageUrl;

  /// Null for a system-event message.
  final AppUser? sender;
  final DateTime createdAt;

  /// True only for a locally-created optimistic echo of the user's own
  /// message, shown instantly while the real request is still in flight —
  /// never true for anything that came from the backend.
  final bool isPending;

  /// Set only on a pending message with an attached photo, before it has
  /// been uploaded — lets the bubble show the picked photo immediately
  /// instead of waiting for a server-hosted [imageUrl].
  final File? localImage;

  factory SwapMessage.fromJson(Map<String, dynamic> json) {
    return SwapMessage(
      id: json['id'] as int,
      swapOfferId: json['swap_offer_id'] as int,
      isSystemEvent: json['message_type'] == 'system_event',
      body: json['body'] as String?,
      imageUrl: json['image_url'] as String?,
      sender: json['sender'] != null
          ? AppUser.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
