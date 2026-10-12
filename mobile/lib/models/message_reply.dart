import 'package:flutter/foundation.dart';

/// Reads an id that may arrive as a number or as a numeric string — a
/// message's own POST response echoes form fields back as strings.
int? parseOptionalId(Object? value) => switch (value) {
  int() => value,
  num() => value.toInt(),
  String() => int.tryParse(value),
  _ => null,
};

/// The quote a reply shows of the message it answers — mirrors
/// `reply_to` on MessageResource/GroupMessageResource.
@immutable
class MessageReply {
  const MessageReply({
    required this.id,
    this.body,
    this.senderName,
    this.imageUrl,
    this.imageCount = 0,
  });

  final int id;
  final String? body;

  /// Null when the original sender has deleted their account.
  final String? senderName;

  /// The original's first photo, if it had any.
  final String? imageUrl;
  final int imageCount;

  factory MessageReply.fromJson(Map<String, dynamic> json) {
    return MessageReply(
      id: parseOptionalId(json['id'])!,
      body: json['body'] as String?,
      senderName: json['sender_name'] as String?,
      imageUrl: json['image_url'] as String?,
      imageCount: parseOptionalId(json['image_count']) ?? 0,
    );
  }

  static MessageReply? tryFromJson(Object? json) =>
      json is Map<String, dynamic> ? MessageReply.fromJson(json) : null;

  /// One line of text for the quote: the caption, or a photo label.
  String get summary {
    final text = body?.trim();
    if (text != null && text.isNotEmpty) return text;
    if (imageCount > 1) return '📷 $imageCount photos';
    if (imageCount == 1) return '📷 Photo';
    return 'Message';
  }
}
