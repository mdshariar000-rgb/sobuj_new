import 'package:flutter/foundation.dart';

/// A user's full UK address — private to them (and admins). Mirrors the
/// `address` object UserResource returns for the signed-in user.
@immutable
class UkAddress {
  const UkAddress({
    required this.line1,
    this.line2,
    required this.city,
    this.county,
    required this.postcode,
  });

  final String line1;
  final String? line2;
  final String city;
  final String? county;
  final String postcode;

  /// The API's `address_*` fields, for sign-up and profile edits.
  Map<String, String> toFields() => {
    'address_line1': line1,
    'address_line2': line2 ?? '',
    'address_city': city,
    'address_county': county ?? '',
    'address_postcode': postcode,
  };

  /// Null when the account has no address yet.
  static UkAddress? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic> || json['postcode'] == null) return null;
    return UkAddress(
      line1: json['line1'] as String? ?? '',
      line2: json['line2'] as String?,
      city: json['city'] as String? ?? '',
      county: json['county'] as String?,
      postcode: json['postcode'] as String,
    );
  }
}

/// One address at a postcode, from Royal Mail's list (see
/// PostcodeAddressService on the backend).
@immutable
class AddressSuggestion {
  const AddressSuggestion({
    required this.id,
    required this.address,
    required this.line1,
    this.line2,
    required this.city,
    this.county,
    this.postcode,
  });

  final String id;

  /// e.g. "12 Cardigan Road, Leeds, LS6 3AF".
  final String address;
  final String line1;
  final String? line2;
  final String city;
  final String? county;

  final String? postcode;

  factory AddressSuggestion.fromJson(Map<String, dynamic> json) =>
      AddressSuggestion(
        id: json['id'] as String,
        address: json['address'] as String,
        line1: json['line1'] as String? ?? '',
        line2: json['line2'] as String?,
        city: json['city'] as String? ?? '',
        county: json['county'] as String?,
        postcode: json['postcode'] as String?,
      );
}
