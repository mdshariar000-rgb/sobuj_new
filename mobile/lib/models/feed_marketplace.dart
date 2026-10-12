import 'package:flutter/foundation.dart';

import 'listing.dart';

/// The marketplace listings mixed into the Home feed — see
/// FeedMarketplaceController on the backend.
@immutable
class FeedMarketplace {
  const FeedMarketplace({
    this.nearby = const [],
    this.fromFollowing = const [],
    this.forYou = const [],
    this.locationLabel,
  });

  /// Fresh listings near the user's registration location, best first —
  /// the "Fresh near you" carousel.
  final List<Listing> nearby;

  /// New listings from growers the user follows, newest first — shown in
  /// the feed as "`name` listed a new item".
  final List<Listing> fromFollowing;

  /// New listings matching what the user recently searched for from Home
  /// — the top of "Picked for you".
  final List<Listing> forYou;

  /// The user's registration location, e.g. "Leeds", for the carousel title.
  final String? locationLabel;

  bool get isEmpty => nearby.isEmpty && fromFollowing.isEmpty && forYou.isEmpty;

  FeedMarketplace copyWith({
    List<Listing>? nearby,
    List<Listing>? fromFollowing,
    List<Listing>? forYou,
  }) {
    return FeedMarketplace(
      nearby: nearby ?? this.nearby,
      fromFollowing: fromFollowing ?? this.fromFollowing,
      forYou: forYou ?? this.forYou,
      locationLabel: locationLabel,
    );
  }

  /// [listing] swapped in wherever it appears (e.g. after saving it).
  FeedMarketplace replacing(Listing listing) {
    List<Listing> swap(List<Listing> list) => [
      for (final item in list)
        if (item.id == listing.id) listing else item,
    ];
    return copyWith(
      nearby: swap(nearby),
      fromFollowing: swap(fromFollowing),
      forYou: swap(forYou),
    );
  }

  factory FeedMarketplace.fromJson(Map<String, dynamic> json) {
    List<Listing> parse(Object? list) => (list as List<dynamic>? ?? const [])
        .map((item) => Listing.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);

    return FeedMarketplace(
      nearby: parse(json['nearby']),
      fromFollowing: parse(json['from_following']),
      forYou: parse(json['for_you']),
      locationLabel: json['location_label'] as String?,
    );
  }
}
