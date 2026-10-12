import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/geo_point.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/listing_category.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/swap_message.dart';
import 'package:shobuj_mobile/models/swap_offer.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/discovery_providers.dart';
import 'package:shobuj_mobile/providers/location_providers.dart';
import 'package:shobuj_mobile/screens/discovery/discovery_screen.dart';
import 'package:shobuj_mobile/screens/discovery/favorites_screen.dart';
import 'package:shobuj_mobile/screens/discovery/swap_offer_thread_screen.dart';
import 'package:shobuj_mobile/screens/discovery/widgets/listing_grid_card.dart';
import 'package:shobuj_mobile/screens/profile/profile_screen.dart';
import 'package:shobuj_mobile/services/api_client.dart';
import 'package:shobuj_mobile/services/swap_offer_realtime_channel.dart';

/// Never actually opens a socket — swaps in for the real realtime channel
/// in tests via a provider override, since the real one would otherwise try
/// to reach production's WebSocket server.
class FakeRealtimeChannel extends SwapOfferRealtimeChannel {
  FakeRealtimeChannel() : super(dio: Dio(), swapOfferId: 0);

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {}
}

/// A stand-in ApiClient that returns a fixed, controllable listing set instead
/// of hitting the network — ApiClient isn't `final`, so overriding just the
/// one method under test is enough.
class FakeApiClient extends ApiClient {
  // The real Dio() is never actually used for I/O here — every method this
  // fake exercises is overridden below.
  FakeApiClient(this.listings) : super(Dio());

  List<Listing> listings;
  Map<String, dynamic>? lastCallArgs;

  @override
  Future<PaginatedResponse<Listing>> nearbyListings({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    String? category,
    TransactionType? transactionType,
    String? search,
    String? sort,
    int page = 1,
  }) async {
    lastCallArgs = {
      'latitude': latitude,
      'longitude': longitude,
      'radiusKm': radiusKm,
      'category': category,
      'transactionType': transactionType,
      'search': search,
      'sort': sort,
      'page': page,
    };

    return PaginatedResponse(
      data: listings,
      currentPage: 1,
      lastPage: 1,
      total: listings.length,
    );
  }

  @override
  Future<List<ListingCategory>> listingCategories() async {
    return const [
      ListingCategory(id: 1, name: 'Seeds & Scions'),
      ListingCategory(id: 2, name: 'Live Plants & Saplings'),
      ListingCategory(id: 3, name: 'Organic Fertilizers'),
      ListingCategory(id: 4, name: 'Farm Tools & Equipment'),
      ListingCategory(id: 5, name: 'Harvest & Produce'),
      ListingCategory(id: 6, name: 'Compost & Soils'),
    ];
  }

  @override
  Future<PaginatedResponse<SwapOffer>> mySwapOffers({int page = 1}) async {
    return const PaginatedResponse(
      data: [],
      currentPage: 1,
      lastPage: 1,
      total: 0,
    );
  }

  @override
  Future<PaginatedResponse<Listing>> savedListings({int page = 1}) async {
    return const PaginatedResponse(
      data: [],
      currentPage: 1,
      lastPage: 1,
      total: 0,
    );
  }

  SwapOffer? createSwapOfferResult;
  int? lastOfferedListingId;

  @override
  Future<SwapOffer> createSwapOffer(int listingId, {String? note}) async {
    lastOfferedListingId = listingId;
    return createSwapOfferResult!;
  }

  @override
  Future<PaginatedResponse<SwapMessage>> swapOfferMessages(
    int swapOfferId, {
    int page = 1,
  }) async {
    return const PaginatedResponse(
      data: [],
      currentPage: 1,
      lastPage: 1,
      total: 0,
    );
  }
}

Listing _buildListing({
  required int id,
  required String title,
  double? distanceKm,
  String? lookingFor,
}) {
  return Listing(
    id: id,
    title: title,
    listingType: 'Seeds & Scions',
    transactionType: TransactionType.swap,
    status: ListingStatus.active,
    lookingFor: lookingFor,
    location: const GeoPoint(latitude: 23.78, longitude: 90.27),
    distanceKm: distanceKm,
    createdAt: DateTime(2026, 1, 1),
  );
}

const _fakeLocation = GeoPoint(latitude: 53.8173, longitude: -1.5776);

void main() {
  testWidgets('shows listings returned by the API in list view', (
    tester,
  ) async {
    final fakeClient = FakeApiClient([
      _buildListing(
        id: 1,
        title: 'Cherry Tomato Seeds',
        distanceKm: 0.9,
        lookingFor: 'Basil',
      ),
      _buildListing(id: 2, title: 'Mint Cuttings', distanceKm: 2.4),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          accountLocationProvider.overrideWith((ref) async => _fakeLocation),
        ],
        child: const MaterialApp(home: DiscoveryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Two-column grid: both cards share the first row, each with its
    // title, deal label and category tag.
    expect(find.text('Cherry Tomato Seeds'), findsOneWidget);
    expect(find.text('Mint Cuttings'), findsOneWidget);
    expect(find.byType(ListingGridCard), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(ListingGridCard),
        matching: find.text('Seeds & Scions'),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('Buy narrows the grid to items for sale, Sell opens the form', (
    tester,
  ) async {
    final fakeClient = FakeApiClient([
      _buildListing(id: 1, title: 'Cherry Tomato Seeds'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          accountLocationProvider.overrideWith((ref) async => _fakeLocation),
        ],
        child: const MaterialApp(home: DiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('marketplace-buy')));
    await tester.pumpAndSettle();
    expect(fakeClient.lastCallArgs?['transactionType'], TransactionType.sell);

    // Tapping Buy again goes back to everything.
    await tester.tap(find.byKey(const Key('marketplace-buy')));
    await tester.pumpAndSettle();
    expect(fakeClient.lastCallArgs?['transactionType'], isNull);

    await tester.tap(find.byKey(const Key('marketplace-sell')));
    await tester.pumpAndSettle();
    expect(find.text('Sell an Item'), findsOneWidget);
  });

  testWidgets('searches around the location chosen at registration', (
    tester,
  ) async {
    final fakeClient = FakeApiClient([]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          accountLocationProvider.overrideWith((ref) async => _fakeLocation),
        ],
        child: const MaterialApp(home: DiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(fakeClient.lastCallArgs?['latitude'], _fakeLocation.latitude);
    expect(fakeClient.lastCallArgs?['longitude'], _fakeLocation.longitude);
  });

  testWidgets('shows an empty state when there are no nearby listings', (
    tester,
  ) async {
    final fakeClient = FakeApiClient([]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          accountLocationProvider.overrideWith((ref) async => _fakeLocation),
        ],
        child: const MaterialApp(home: DiscoveryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('No listings found'), findsOneWidget);
  });

  testWidgets(
    'typing in the search bar debounces then calls the API with the term',
    (tester) async {
      final fakeClient = FakeApiClient([
        _buildListing(id: 1, title: 'Cherry Tomato Seeds'),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            accountLocationProvider.overrideWith((ref) async => _fakeLocation),
          ],
          child: const MaterialApp(home: DiscoveryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'tomato');

      // Debounce is 400ms — before it elapses, no call carrying the new term
      // should have fired yet (the initial load call used the empty default).
      await tester.pump(const Duration(milliseconds: 200));
      expect(fakeClient.lastCallArgs?['search'], isNot('tomato'));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(fakeClient.lastCallArgs?['search'], 'tomato');
    },
  );

  testWidgets('choosing a category in Filters refetches with that category', (
    tester,
  ) async {
    final fakeClient = FakeApiClient([
      _buildListing(id: 1, title: 'Cherry Tomato Seeds'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          accountLocationProvider.overrideWith((ref) async => _fakeLocation),
        ],
        child: const MaterialApp(home: DiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Category is picked in the Filters sheet and only applies on "Apply".
    await tester.tap(find.byKey(const Key('discovery-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Seeds & Scions'),
      ),
    );
    await tester.pumpAndSettle();
    expect(fakeClient.lastCallArgs?['category'], isNull);
    await tester.tap(find.byKey(const Key('filter-apply')));
    await tester.pumpAndSettle();

    expect(fakeClient.lastCallArgs?['category'], 'Seeds & Scions');

    // Clear All + Apply removes it again.
    await tester.tap(find.byKey(const Key('discovery-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('filter-clear-all')));
    await tester.tap(find.byKey(const Key('filter-apply')));
    await tester.pumpAndSettle();

    expect(fakeClient.lastCallArgs?['category'], isNull);
  });

  testWidgets('the chat button on a card opens the conversation', (
    tester,
  ) async {
    final listing = _buildListing(id: 1, title: 'Cherry Tomato Seeds');
    final fakeClient = FakeApiClient([listing]);
    fakeClient.createSwapOfferResult = SwapOffer(
      id: 42,
      status: SwapOfferStatus.pending,
      listing: listing,
      requester: AppUser(
        id: 9,
        name: 'Me',
        ratingAvg: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
      createdAt: DateTime(2026, 1, 2),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          accountLocationProvider.overrideWith((ref) async => _fakeLocation),
          swapOfferRealtimeChannelProvider.overrideWith(
            (ref, swapOfferId) => FakeRealtimeChannel(),
          ),
        ],
        child: const MaterialApp(home: DiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('listing-chat-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('listing-chat-1')));
    await tester.pumpAndSettle();

    expect(find.byType(SwapOfferThreadScreen), findsOneWidget);
    expect(fakeClient.lastOfferedListingId, 1);
  });

  testWidgets(
    'explains when the account has no location, with a retry action',
    (tester) async {
      final fakeClient = FakeApiClient([]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            accountLocationProvider.overrideWith(
              (ref) async => throw const AccountLocationMissingException(),
            ),
          ],
          child: const MaterialApp(home: DiscoveryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Your account has no location set'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
    },
  );

  testWidgets('the header has no promotional description card, and its avatar/'
      'favorites icons open the right screens', (tester) async {
    final fakeClient = FakeApiClient([]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          accountLocationProvider.overrideWith((ref) async => _fakeLocation),
        ],
        child: const MaterialApp(home: DiscoveryScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // The old white "Marketplace / Buy, sell, and trade..." card (with a
    // second, redundant avatar+heart pair) is gone — the brand bar is the
    // header now.
    expect(find.textContaining('Buy, sell, and trade'), findsNothing);
    expect(find.text('Marketplace'), findsNothing);

    await tester.tap(find.byKey(const Key('profile-avatar-button')));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(ProfileScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Favorites'));
    await tester.pumpAndSettle();
    expect(find.byType(FavoritesScreen), findsOneWidget);
  });

  testWidgets(
    'lays out without overflow at a real phone width (not the wider default test surface)',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final fakeClient = FakeApiClient([
        _buildListing(
          id: 1,
          title: 'Cherry Tomato Seeds',
          distanceKm: 0.9,
          lookingFor: 'Basil',
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            accountLocationProvider.overrideWith((ref) async => _fakeLocation),
          ],
          child: const MaterialApp(home: DiscoveryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
