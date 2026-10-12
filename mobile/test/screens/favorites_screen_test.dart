import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/discovery/favorites_screen.dart';

import '../support/fake_api_client.dart';

class FavoritesFakeApiClient extends FakeApiClient {
  List<Listing> saved = const [];
  int? lastUnsavedListingId;

  @override
  Future<PaginatedResponse<Listing>> savedListings({int page = 1}) async {
    return PaginatedResponse(
      data: saved,
      currentPage: 1,
      lastPage: 1,
      total: saved.length,
    );
  }

  @override
  Future<Listing> unsaveListing(int listingId) async {
    lastUnsavedListingId = listingId;
    final listing = saved.firstWhere((l) => l.id == listingId);
    return listing.copyWith(isSaved: false);
  }
}

Listing _buildListing({required int id, required String title, double? price}) {
  return Listing(
    id: id,
    title: title,
    listingType: 'Seeds & Scions',
    transactionType: price != null
        ? TransactionType.sell
        : TransactionType.swap,
    status: ListingStatus.active,
    price: price,
    isSaved: true,
    owner: AppUser(
      id: 99,
      name: 'A Grower',
      ratingAvg: 0,
      createdAt: DateTime(2026, 1, 1),
    ),
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  testWidgets('shows saved listings', (tester) async {
    final fakeClient = FavoritesFakeApiClient();
    fakeClient.saved = [
      _buildListing(id: 1, title: 'Heirloom Tomato Seeds', price: 3.5),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(fakeClient)],
        child: const MaterialApp(home: FavoritesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Heirloom Tomato Seeds'), findsOneWidget);
  });

  testWidgets('shows an empty state when nothing is saved', (tester) async {
    final fakeClient = FavoritesFakeApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(fakeClient)],
        child: const MaterialApp(home: FavoritesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No favorites yet'), findsOneWidget);
  });

  testWidgets('unsaving a listing removes it from the list', (tester) async {
    final fakeClient = FavoritesFakeApiClient();
    fakeClient.saved = [
      _buildListing(id: 1, title: 'Heirloom Tomato Seeds', price: 3.5),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(fakeClient)],
        child: const MaterialApp(home: FavoritesScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    expect(fakeClient.lastUnsavedListingId, 1);
    expect(find.textContaining('No favorites yet'), findsOneWidget);
  });

  testWidgets(
    'lays out without overflow at a real phone width (not the wider default test surface)',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final fakeClient = FavoritesFakeApiClient();
      fakeClient.saved = [
        _buildListing(id: 1, title: 'Heirloom Tomato Seeds', price: 3.5),
        _buildListing(id: 2, title: 'Mint Cuttings'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(fakeClient)],
          child: const MaterialApp(home: FavoritesScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
