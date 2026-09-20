import 'package:flutter/foundation.dart';

import 'app_user.dart';

/// Mirrors AppNotificationResource on the backend — the app's real
/// in-app notification inbox (post liked/commented, comment replied to,
/// a swap-offer or group message received).
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.actor,
    this.readAt,
    required this.createdAt,
  });

  final int id;

  /// One of: post_liked, post_commented, comment_replied,
  /// swap_message_received, group_message_received — see
  /// App\Enums\NotificationType on the backend.
  final String type;
  final String title;
  final String body;

  /// Deep-link payload — shape varies by [type] (post_id/comment_id,
  /// swap_offer_id, group_id, etc.). See the notification-tap routing in
  /// PushNotificationService.
  final Map<String, dynamic>? data;
  final AppUser? actor;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      actor: actor,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      data: json['data'] as Map<String, dynamic>?,
      actor: json['actor'] != null
          ? AppUser.fromJson(json['actor'] as Map<String, dynamic>)
          : null,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
