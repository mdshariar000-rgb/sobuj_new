import 'package:flutter/foundation.dart';

import 'app_user.dart';
import 'enums.dart';
import 'geo_point.dart';
import 'listing_photo.dart';

@immutable
class Listing {
  const Listing({
    required this.id,
    required this.title,
    this.variety,
    this.description,
    this.condition,
    required this.listingType,
    required this.transactionType,
    this.price,
    this.quantity,
    this.contact,
    required this.status,
    this.lookingFor,
    this.handoverNote,
    this.location,
    this.distanceKm,
    this.photos = const [],
    this.isSaved,
    this.owner,
    this.viewsCount = 0,
    this.averageRating,
    this.reviewsCount,
    this.canReview,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String? variety;
  final String? description;
  final ListingCondition? condition;
  final String listingType;
  final TransactionType transactionType;
  final double? price;

  /// How many units are on offer ("Quantity available") — null on listings
  /// posted before the field existed, and on swap/wanted listings.
  final int? quantity;

  /// The seller's phone number or email, as typed on the Sell form. Private:
  /// the API only returns it to the seller themselves (buyers ask in chat),
  /// so it's null for everyone else and on older listings.
  final String? contact;
  final ListingStatus status;
  final String? lookingFor;
  final String? handoverNote;

  /// Fuzzed pickup location — see GeoPoint. This is what map pins are plotted
  /// with; it is never the listing's exact coordinates.
  final GeoPoint? location;

  /// Only present when this listing came from the nearby-search endpoint
  /// (Listing::scopeNearby on the backend) — null for e.g. "my listings".
  final double? distanceKm;

  final List<ListingPhoto> photos;

  /// Only present when authenticated — see ListingResource::is_saved.
  final bool? isSaved;
  final AppUser? owner;

  /// Real count of non-owner views (ListingController::show() increments
  /// it) — 0 rather than null when absent, since the field always exists.
  final int viewsCount;

  /// Only present on a single-listing fetch (ListingController::show()
  /// loads the aggregate) — null on list endpoints that don't compute it.
  final double? averageRating;
  final int? reviewsCount;

  /// Only on a single-listing fetch: whether the signed-in user completed a
  /// deal for this listing and so may review it.
  final bool? canReview;
  final DateTime createdAt;

  String? get thumbnailUrl => photos.isEmpty ? null : photos.first.url;

  Listing copyWith({bool? isSaved, double? averageRating, int? reviewsCount}) {
    return Listing(
      id: id,
      title: title,
      variety: variety,
      description: description,
      condition: condition,
      listingType: listingType,
      transactionType: transactionType,
      price: price,
      quantity: quantity,
      contact: contact,
      status: status,
      lookingFor: lookingFor,
      handoverNote: handoverNote,
      location: location,
      distanceKm: distanceKm,
      photos: photos,
      isSaved: isSaved ?? this.isSaved,
      owner: owner,
      viewsCount: viewsCount,
      averageRating: averageRating ?? this.averageRating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      canReview: canReview,
      createdAt: createdAt,
    );
  }

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      id: json['id'] as int,
      title: json['title'] as String,
      variety: json['variety'] as String?,
      description: json['description'] as String?,
      condition: json['condition'] != null
          ? ListingCondition.fromValue(json['condition'] as String)
          : null,
      listingType: json['listing_type'] as String,
      transactionType: TransactionType.fromValue(
        json['transaction_type'] as String,
      ),
      price: (json['price'] as num?)?.toDouble(),
      quantity: (json['quantity'] as num?)?.toInt(),
      contact: json['contact'] as String?,
      status: ListingStatus.fromValue(json['status'] as String),
      lookingFor: json['looking_for'] as String?,
      handoverNote: json['handover_note'] as String?,
      location: GeoPoint.tryFromJson(json['location']),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      photos: (json['photos'] as List<dynamic>? ?? const [])
          .map((photo) => ListingPhoto.fromJson(photo as Map<String, dynamic>))
          .toList(growable: false),
      isSaved: json['is_saved'] as bool?,
      owner: json['owner'] != null
          ? AppUser.fromJson(json['owner'] as Map<String, dynamic>)
          : null,
      viewsCount: json['views_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble(),
      reviewsCount: json['reviews_count'] as int?,
      canReview: json['can_review'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
