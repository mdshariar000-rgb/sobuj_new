import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'geo_point.dart';
import 'uk_address.dart';

/// Named AppUser (not User) to avoid clashing with other packages' own User
/// types (auth SDKs commonly export one).
@immutable
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.isSuspended,
    this.suspensionReason,
    this.isVerified,
    this.username,
    this.bio,
    this.avatarUrl,
    this.coverPhotoUrl,
    this.locationLabel,
    this.address,
    this.needsAddress = false,
    this.hasPassword = true,
    this.signedInWith = const [],
    this.growingInterests = const [],
    this.showHandoverRadius,
    this.experienceLevel,
    this.growingSetup,
    required this.ratingAvg,
    this.location,
    this.postsCount,
    this.activeListingsCount,
    this.followersCount,
    this.followingCount,
    this.isFollowing,
    this.sellerRating,
    this.sellerReviewsCount,
    this.completedDealsCount,
    required this.createdAt,
  });

  final int id;
  final String name;

  /// email/phone/isSuspended/suspensionReason/showHandoverRadius are only
  /// present when this is the signed-in user's own record — see
  /// UserResource on the backend. isVerified, by contrast, is a public trust
  /// signal shown on any seller's listing/profile card, not just their own.
  final String? email;
  final String? phone;
  final bool? isSuspended;
  final String? suspensionReason;
  final bool? isVerified;
  final bool? showHandoverRadius;

  final String? username;
  final String? bio;
  final String? avatarUrl;
  final String? coverPhotoUrl;

  /// A free-text label the user typed themselves (e.g. "Napa Valley, CA") —
  /// never derived from their real coordinates, which stay fuzzed/private.
  final String? locationLabel;

  /// Only on the signed-in user's own record — never other people's.
  final UkAddress? address;

  /// An account made before the address was required — AuthGate asks for
  /// it before anything else.
  final bool needsAddress;

  /// False for an account made with Google/Apple that never set a
  /// password — deleting it confirms with that provider instead.
  final bool hasPassword;

  /// "google" / "apple" — linked sign-in providers (own record only).
  final List<String> signedInWith;

  /// A short personal list the user manages themselves — not a moderated or
  /// searchable tag catalog.
  final List<String> growingInterests;

  final ExperienceLevel? experienceLevel;
  final GrowingSetup? growingSetup;
  final double ratingAvg;

  /// Fuzzed location — see GeoPoint. Null (even for one's own profile) when
  /// viewed by someone else and that user has turned off Community Handover
  /// Radius — see ListingResource/UserResource on the backend.
  final GeoPoint? location;

  /// Only present where the backend eager-loads these counts (currently
  /// GET/PATCH /auth/me) — real counts of this user's own posts/active
  /// listings, not shown when null.
  final int? postsCount;
  final int? activeListingsCount;

  /// Follow-graph counts — present on GET/PATCH /auth/me, GET /users/{id},
  /// and the follow/unfollow response. See FollowController on the backend.
  final int? followersCount;
  final int? followingCount;

  /// Whether the signed-in caller currently follows this user. Only
  /// meaningful (non-null) when viewing someone else's profile — never set
  /// on the caller's own record.
  final bool? isFollowing;

  /// Trust signals, only on GET /users/{id} (UserController::show()): the
  /// average rating buyers gave this grower's listings (null with no
  /// reviews), how many reviews that is, and how many deals they completed.
  final double? sellerRating;
  final int? sellerReviewsCount;
  final int? completedDealsCount;

  final DateTime createdAt;

  AppUser copyWith({
    String? name,
    String? username,
    String? bio,
    String? phone,
    String? avatarUrl,
    String? coverPhotoUrl,
    String? locationLabel,
    UkAddress? address,
    bool? needsAddress,
    List<String>? growingInterests,
    bool? showHandoverRadius,
    ExperienceLevel? experienceLevel,
    GrowingSetup? growingSetup,
    int? postsCount,
    int? activeListingsCount,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
  }) {
    return AppUser(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      isSuspended: isSuspended,
      suspensionReason: suspensionReason,
      isVerified: isVerified,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      coverPhotoUrl: coverPhotoUrl ?? this.coverPhotoUrl,
      locationLabel: locationLabel ?? this.locationLabel,
      address: address ?? this.address,
      needsAddress: needsAddress ?? this.needsAddress,
      hasPassword: hasPassword,
      signedInWith: signedInWith,
      growingInterests: growingInterests ?? this.growingInterests,
      showHandoverRadius: showHandoverRadius ?? this.showHandoverRadius,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      growingSetup: growingSetup ?? this.growingSetup,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      isFollowing: isFollowing ?? this.isFollowing,
      ratingAvg: ratingAvg,
      location: location,
      postsCount: postsCount ?? this.postsCount,
      activeListingsCount: activeListingsCount ?? this.activeListingsCount,
      sellerRating: sellerRating,
      sellerReviewsCount: sellerReviewsCount,
      completedDealsCount: completedDealsCount,
      createdAt: createdAt,
    );
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      isSuspended: json['is_suspended'] as bool?,
      suspensionReason: json['suspension_reason'] as String?,
      isVerified: json['is_verified'] as bool?,
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      coverPhotoUrl: json['cover_photo_url'] as String?,
      locationLabel: json['location_label'] as String?,
      address: UkAddress.tryFromJson(json['address']),
      needsAddress: json['needs_address'] as bool? ?? false,
      hasPassword: json['has_password'] as bool? ?? true,
      signedInWith:
          (json['signed_in_with'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      growingInterests:
          (json['growing_interests'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      showHandoverRadius: json['show_handover_radius'] as bool?,
      experienceLevel: json['experience_level'] != null
          ? ExperienceLevel.fromValue(json['experience_level'] as String)
          : null,
      growingSetup: json['growing_setup'] != null
          ? GrowingSetup.fromValue(json['growing_setup'] as String)
          : null,
      ratingAvg: (json['rating_avg'] as num).toDouble(),
      location: GeoPoint.tryFromJson(json['location']),
      postsCount: json['posts_count'] as int?,
      activeListingsCount: json['active_listings_count'] as int?,
      followersCount: json['followers_count'] as int?,
      followingCount: json['following_count'] as int?,
      isFollowing: json['is_following'] as bool?,
      sellerRating: (json['seller_rating'] as num?)?.toDouble(),
      sellerReviewsCount: json['seller_reviews_count'] as int?,
      completedDealsCount: json['completed_deals_count'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
