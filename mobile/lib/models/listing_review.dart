import 'package:flutter/foundation.dart';

import 'app_user.dart';

/// Mirrors ListingReviewResource on the backend.
@immutable
class ListingReview {
  const ListingReview({
    required this.id,
    required this.listingId,
    required this.rating,
    this.comment,
    this.reviewer,
    required this.createdAt,
  });

  final int id;
  final int listingId;
  final int rating;
  final String? comment;
  final AppUser? reviewer;
  final DateTime createdAt;

  factory ListingReview.fromJson(Map<String, dynamic> json) {
    return ListingReview(
      id: json['id'] as int,
      listingId: json['listing_id'] as int,
      rating: json['rating'] as int,
      comment: json['comment'] as String?,
      reviewer: json['reviewer'] != null
          ? AppUser.fromJson(json['reviewer'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
