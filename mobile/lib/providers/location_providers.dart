import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/geo_point.dart';
import 'auth_providers.dart';

/// The signed-in account has no location on file — only possible for older
/// accounts, since registration now requires picking a UK place or postcode.
class AccountLocationMissingException implements Exception {
  const AccountLocationMissingException();

  @override
  String toString() => 'Your account has no location set.';
}

/// The location the user chose when registering, which the marketplace
/// searches around and centres its map on — Agro Hub never reads the
/// device's GPS.
///
/// This is the account's *fuzzed* location from GET /auth/me (500–1000 m
/// off the real point), which is plenty for a search measured in kilometres
/// and matches how listings themselves are located.
final accountLocationProvider = FutureProvider.autoDispose<GeoPoint>((
  ref,
) async {
  final location = ref.watch(authControllerProvider).valueOrNull?.location;
  if (location == null) throw const AccountLocationMissingException();
  return location;
});
