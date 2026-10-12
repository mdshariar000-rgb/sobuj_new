import 'package:flutter/foundation.dart';

import 'app_user.dart';
import 'comment.dart';

/// Mirrors PostResource on the backend: a post in a group's discussion
/// thread. Every post lives in a group — there's no personal timeline.
@immutable
class Post {
  const Post({
    required this.id,
    this.groupId,
    this.groupName,
    required this.body,
    this.approvalStatus = 'approved',
    this.imageUrl,
    this.canShare = false,
    this.commentsCount,
    this.likesCount,
    this.likedByMe,
    this.author,
    this.comments,
    required this.createdAt,
  });

  final int id;

  /// Always set on posts from the current server; nullable only so an
  /// unexpected payload can't crash parsing.
  final int? groupId;

  /// Set where the backend includes the group (e.g. a profile's post list),
  /// so the card can say which group the post is from.
  final String? groupName;
  final String body;

  /// 'approved', 'pending', or 'rejected' — see PostResource::approval_status
  /// on the backend. Only ever 'pending'/'rejected' for a non-admin member's
  /// post into a *private* group (see PostController::store()).
  final String approvalStatus;
  final String? imageUrl;

  /// Whether "Share" (to other apps) is offered — only for posts in a public
  /// group; a private group's posts never leave the group.
  final bool canShare;
  final int? commentsCount;
  final int? likesCount;

  /// Only present when authenticated — see PostResource::liked_by_me.
  final bool? likedByMe;
  final AppUser? author;
  final List<Comment>? comments;
  final DateTime createdAt;

  bool get isPendingApproval => approvalStatus == 'pending';
  bool get isRejected => approvalStatus == 'rejected';

  Post copyWith({
    int? commentsCount,
    int? likesCount,
    bool? likedByMe,
    String? approvalStatus,
  }) {
    return Post(
      id: id,
      groupId: groupId,
      groupName: groupName,
      body: body,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      imageUrl: imageUrl,
      canShare: canShare,
      commentsCount: commentsCount ?? this.commentsCount,
      likesCount: likesCount ?? this.likesCount,
      likedByMe: likedByMe ?? this.likedByMe,
      author: author,
      comments: comments,
      createdAt: createdAt,
    );
  }

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      groupId: json['group_id'] as int?,
      groupName: (json['group'] as Map<String, dynamic>?)?['name'] as String?,
      body: json['body'] as String,
      approvalStatus: json['approval_status'] as String? ?? 'approved',
      imageUrl: json['image_url'] as String?,
      canShare: json['can_share'] as bool? ?? false,
      commentsCount: json['comments_count'] as int?,
      likesCount: json['likes_count'] as int?,
      likedByMe: json['liked_by_me'] as bool?,
      author: json['author'] != null
          ? AppUser.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      comments: json['comments'] != null
          ? (json['comments'] as List<dynamic>)
                .map((item) => Comment.fromJson(item as Map<String, dynamic>))
                .toList(growable: false)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
