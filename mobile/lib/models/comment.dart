import 'package:flutter/foundation.dart';

import 'app_user.dart';

/// Mirrors CommentResource on the backend.
@immutable
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.body,
    this.author,
    this.replyingToName,
    required this.createdAt,
  });

  final int id;
  final int postId;

  /// Null for a top-level comment. Always points at a top-level comment
  /// (never another reply) — replying to a reply flattens into the same
  /// thread one level deep, same as Facebook/Instagram.
  final int? parentId;
  final String body;
  final AppUser? author;

  /// The specific person this reply is addressing, for the bold name prefix
  /// — may differ from the top-level comment's author when replying to a
  /// reply. Null for top-level comments.
  final String? replyingToName;
  final DateTime createdAt;

  bool get isReply => parentId != null;

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as int,
      postId: json['post_id'] as int,
      parentId: json['parent_id'] as int?,
      body: json['body'] as String,
      author: json['author'] != null
          ? AppUser.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      replyingToName: json['replying_to_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
