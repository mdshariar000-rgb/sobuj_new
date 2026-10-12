import 'package:shobuj_mobile/models/uk_location.dart';
import 'package:shobuj_mobile/services/uk_location_service.dart';

/// Answers every search with the same fixed places, filtered by a simple
/// case-insensitive prefix match — enough to drive the registration form
/// without hitting postcodes.io.
class FakeUkLocationService extends UkLocationService {
  FakeUkLocationService();

  static const places = [
    UkLocation(
      name: 'Headingley',
      detail: 'Leeds, England',
      latitude: 53.8173,
      longitude: -1.5776,
    ),
    UkLocation(
      name: 'Cardiff',
      detail: 'Wales',
      latitude: 51.4816,
      longitude: -3.1791,
    ),
  ];

  /// Postcodes this fake knows: LS6 3AA (Headingley) and CF10 1AA
  /// (Cardiff). Anything else is "not found".
  static const postcodes = {
    'LS6 3AA': UkLocation(
      name: 'Headingley',
      detail: 'Leeds, England',
      latitude: 53.8173,
      longitude: -1.5776,
      town: 'Leeds',
    ),
    'CF10 1AA': UkLocation(
      name: 'Cardiff',
      detail: 'Wales',
      latitude: 51.4816,
      longitude: -3.1791,
      town: 'Cardiff',
    ),
  };

  @override
  Future<UkLocation?> lookupPostcode(String postcode) async =>
      postcodes[postcode.trim().toUpperCase()];

  @override
  Future<List<UkLocation>> search(String query) async {
    final q = query.trim().toLowerCase();
    return places.where((p) => p.name.toLowerCase().startsWith(q)).toList();
  }
}
