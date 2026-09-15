import 'package:flutter/foundation.dart';

import 'app_user.dart';

/// Mirrors GroupJoinRequestResource on the backend — one real, pending
/// request to join a private group, for the group admin's moderation queue.
@immutable
class GroupJoinRequest {
  const GroupJoinRequest({
    required this.id,
    required this.user,
    this.requestedAt,
  });

  final int id;
  final AppUser user;
  final DateTime? requestedAt;

  factory GroupJoinRequest.fromJson(Map<String, dynamic> json) {
    return GroupJoinRequest(
      id: json['id'] as int,
      user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
      requestedAt: json['requested_at'] != null
          ? DateTime.parse(json['requested_at'] as String)
          : null,
    );
  }
}
