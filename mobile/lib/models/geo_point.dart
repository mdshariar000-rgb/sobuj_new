import 'package:flutter/foundation.dart';

/// A fuzzed (or, server-side only, exact) coordinate pair. Every GeoPoint that
/// reaches the mobile app is the *fuzzed* location — see the backend's
/// HasFuzzyLocation trait — never the user's or listing's real position.
@immutable
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  factory GeoPoint.fromJson(Map<String, dynamic> json) {
    return GeoPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  static GeoPoint? tryFromJson(Object? json) {
    if (json == null) return null;
    return GeoPoint.fromJson(json as Map<String, dynamic>);
  }

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GeoPoint &&
          other.latitude == latitude &&
          other.longitude == longitude);

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
