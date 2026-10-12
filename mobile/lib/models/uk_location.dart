import 'package:flutter/foundation.dart';

/// A UK place or postcode a user picks as their base location when
/// registering, instead of sharing the device's GPS position. The backend
/// fuzzes these coordinates before any other user sees them, the same as a
/// GPS position.
@immutable
class UkLocation {
  const UkLocation({
    required this.name,
    required this.detail,
    required this.latitude,
    required this.longitude,
    this.town,
    this.county,
  });

  /// The place name or postcode, e.g. "Headingley" or "LS6 3AA".
  final String name;

  /// Where it is, e.g. "Leeds, England" — tells apart the several St Iveses.
  final String detail;

  final double latitude;
  final double longitude;

  /// From a full-postcode lookup only — prefills an address form.
  final String? town;
  final String? county;

  /// What's sent as the account's location_label.
  String get label => detail.isEmpty ? name : '$name, $detail';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UkLocation &&
          other.name == name &&
          other.detail == detail &&
          other.latitude == latitude &&
          other.longitude == longitude);

  @override
  int get hashCode => Object.hash(name, detail, latitude, longitude);
}
