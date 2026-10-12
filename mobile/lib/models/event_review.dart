import 'package:flutter/foundation.dart';

import 'app_user.dart';

/// A review or comment on an event — the rating is optional, so a plain
/// comment has none. Mirrors EventReviewResource on the backend.
@immutable
class EventReview {
  const EventReview({
    required this.id,
    required this.eventId,
    this.rating,
    this.body,
    this.user,
    required this.createdAt,
  });

  final int id;
  final int eventId;
  final int? rating;
  final String? body;
  final AppUser? user;
  final DateTime createdAt;

  factory EventReview.fromJson(Map<String, dynamic> json) {
    return EventReview(
      id: json['id'] as int,
      eventId: json['event_id'] as int,
      rating: json['rating'] as int?,
      body: json['body'] as String?,
      user: json['user'] != null
          ? AppUser.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
