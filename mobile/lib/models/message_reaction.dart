import 'package:flutter/foundation.dart';

import 'message_reply.dart';

/// The quick reactions offered on a chat message — must match
/// REACTION_EMOJIS on the backend (HasMessageImages).
const reactionEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

/// One emoji's reactions on a message — mirrors an entry of `reactions` on
/// MessageResource/GroupMessageResource.
@immutable
class MessageReaction {
  const MessageReaction({required this.emoji, required this.userIds});

  final String emoji;

  /// Who reacted with it — the app highlights the chip if this includes
  /// the signed-in user.
  final List<int> userIds;

  int get count => userIds.length;

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      emoji: json['emoji'] as String,
      userIds: [
        for (final id in (json['user_ids'] as List? ?? const []))
          ?parseOptionalId(id),
      ],
    );
  }

  static List<MessageReaction> listFromJson(Object? json) => [
    if (json is List)
      for (final item in json.whereType<Map<String, dynamic>>())
        MessageReaction.fromJson(item),
  ];
}

/// The reactions after [userId] taps [emoji]: tapping their current emoji
/// removes it, any other emoji replaces it — one reaction per person, same
/// as the backend. Emoji keep their order; a new one goes last.
List<MessageReaction> toggleReaction(
  List<MessageReaction> reactions, {
  required int userId,
  required String emoji,
}) {
  final hadThis = reactions.any(
    (r) => r.emoji == emoji && r.userIds.contains(userId),
  );

  final updated = [
    for (final r in reactions)
      MessageReaction(
        emoji: r.emoji,
        userIds: [
          for (final id in r.userIds)
            if (id != userId) id,
          if (!hadThis && r.emoji == emoji) userId,
        ],
      ),
  ];
  if (!hadThis && !updated.any((r) => r.emoji == emoji)) {
    updated.add(MessageReaction(emoji: emoji, userIds: [userId]));
  }
  return updated.where((r) => r.userIds.isNotEmpty).toList();
}

/// The emoji [userId] reacted with, if any.
String? myReaction(List<MessageReaction> reactions, int? userId) {
  if (userId == null) return null;
  for (final r in reactions) {
    if (r.userIds.contains(userId)) return r.emoji;
  }
  return null;
}
