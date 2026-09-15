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
    required this.status,
    this.lookingFor,
    this.handoverNote,
    this.location,
    this.distanceKm,
    this.photos = const [],
    this.isSaved,
    this.owner,
    this.viewsCount = 0,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String? variety;
  final String? description;
  final ListingCondition? condition;
  final ListingType listingType;
  final TransactionType transactionType;
  final double? price;
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
  final DateTime createdAt;

  String? get thumbnailUrl => photos.isEmpty ? null : photos.first.url;

  Listing copyWith({bool? isSaved}) {
    return Listing(
      id: id,
      title: title,
      variety: variety,
      description: description,
      condition: condition,
      listingType: listingType,
      transactionType: transactionType,
      price: price,
      status: status,
      lookingFor: lookingFor,
      handoverNote: handoverNote,
      location: location,
      distanceKm: distanceKm,
      photos: photos,
      isSaved: isSaved ?? this.isSaved,
      owner: owner,
      viewsCount: viewsCount,
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
      listingType: ListingType.fromValue(json['listing_type'] as String),
      transactionType: TransactionType.fromValue(
        json['transaction_type'] as String,
      ),
      price: (json['price'] as num?)?.toDouble(),
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
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
