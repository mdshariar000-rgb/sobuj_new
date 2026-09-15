import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/listing.dart';

void main() {
  group('Listing.fromJson', () {
    test('parses a full nearby-search response item', () {
      final json = {
        'id': 1,
        'title': 'Cherry Tomato Seeds',
        'variety': 'Sweet 100',
        'listing_type': 'seeds_scions',
        'transaction_type': 'swap',
        'price': null,
        'status': 'active',
        'looking_for': 'Basil cuttings',
        'location': {'latitude': 23.77445841, 'longitude': 90.28577483},
        'distance_km': 0.92,
        'photos': [
          {'id': 1, 'url': 'https://example.com/photo.jpg', 'sort_order': 0},
        ],
        'owner': {
          'id': 5,
          'name': 'Rina',
          'rating_avg': 4.5,
          'location': {'latitude': 23.78, 'longitude': 90.27},
          'created_at': '2026-01-01T00:00:00+00:00',
        },
        'created_at': '2026-01-02T00:00:00+00:00',
        'updated_at': '2026-01-02T00:00:00+00:00',
      };

      final listing = Listing.fromJson(json);

      expect(listing.id, 1);
      expect(listing.title, 'Cherry Tomato Seeds');
      expect(listing.listingType, ListingType.seedsScions);
      expect(listing.transactionType, TransactionType.swap);
      expect(listing.status, ListingStatus.active);
      expect(listing.price, isNull);
      expect(listing.location?.latitude, 23.77445841);
      expect(listing.distanceKm, 0.92);
      expect(listing.thumbnailUrl, 'https://example.com/photo.jpg');
      expect(listing.owner?.name, 'Rina');
    });

    test('handles a "my listings" item with no distance, photos, or owner', () {
      final json = {
        'id': 2,
        'title': 'Mint Cuttings',
        'variety': null,
        'listing_type': 'live_plants',
        'transaction_type': 'free',
        'price': null,
        'status': 'active',
        'looking_for': null,
        'location': {'latitude': 23.78, 'longitude': 90.27},
        'photos': [],
        'created_at': '2026-01-02T00:00:00+00:00',
        'updated_at': '2026-01-02T00:00:00+00:00',
      };

      final listing = Listing.fromJson(json);

      expect(listing.distanceKm, isNull);
      expect(listing.thumbnailUrl, isNull);
      expect(listing.owner, isNull);
      expect(listing.photos, isEmpty);
    });

    test('parses a priced (sell) listing', () {
      final json = {
        'id': 3,
        'title': 'Rare Orchid',
        'variety': null,
        'listing_type': 'live_plants',
        'transaction_type': 'sell',
        'price': 25.5,
        'status': 'active',
        'looking_for': null,
        'location': null,
        'photos': [],
        'created_at': '2026-01-02T00:00:00+00:00',
        'updated_at': '2026-01-02T00:00:00+00:00',
      };

      final listing = Listing.fromJson(json);

      expect(listing.price, 25.5);
      expect(listing.transactionType, TransactionType.sell);
      expect(listing.location, isNull);
    });
  });
}
