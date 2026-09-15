import 'package:flutter/foundation.dart';

import 'app_user.dart';
import 'comment.dart';

/// The app's built-in fallback post category — always present (see the
/// backend's post_categories migration), used when nothing else is picked.
const kDefaultPostCategory = 'General';

/// Mirrors PostResource on the backend. Serves both the general Home Feed
/// (groupId null) and a group's discussion thread (groupId set) — see
/// Post::scopeGeneralFeed() on the backend.
///
/// category is a plain, admin-managed name (see models/post_category.dart
/// and the Home tab's Recent/Disease Alerts/Harvests chips) rather than a
/// fixed enum — an admin can add or rename categories from the web panel at
/// any time.
@immutable
class Post {
  const Post({
    required this.id,
    this.groupId,
    required this.body,
    this.category = kDefaultPostCategory,
    this.approvalStatus = 'approved',
    this.imageUrl,
    this.commentsCount,
    this.likesCount,
    this.likedByMe,
    this.author,
    this.comments,
    required this.createdAt,
  });

  final int id;
  final int? groupId;
  final String body;
  final String category;

  /// 'approved', 'pending', or 'rejected' — see PostResource::approval_status
  /// on the backend. Only ever 'pending'/'rejected' for a non-admin member's
  /// post into a *private* group (see PostController::store()); every Home
  /// Feed post and every public-group post is always 'approved'.
  final String approvalStatus;
  final String? imageUrl;
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
      body: body,
      category: category,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      imageUrl: imageUrl,
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
      body: json['body'] as String,
      category: json['category'] as String? ?? kDefaultPostCategory,
      approvalStatus: json['approval_status'] as String? ?? 'approved',
      imageUrl: json['image_url'] as String?,
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
