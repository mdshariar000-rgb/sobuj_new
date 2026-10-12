import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/feed_marketplace.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/search_results.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/shell_providers.dart';
import 'package:shobuj_mobile/screens/home/grow_now_screen.dart';
import 'package:shobuj_mobile/screens/home/home_feed_screen.dart';
import 'package:shobuj_mobile/screens/home/search_results_screen.dart';
import 'package:shobuj_mobile/screens/home/weather_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Listing _listing(int id, String title) => Listing(
  id: id,
  title: title,
  listingType: 'Live Plants & Saplings',
  transactionType: TransactionType.sell,
  price: 3,
  status: ListingStatus.active,
  distanceKm: 1.2,
  createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
);

FakeApiClient _clientWithListings() => FakeApiClient()
  ..feedMarketplaceResult = FeedMarketplace(
    locationLabel: 'Leeds',
    nearby: [_listing(1, 'Cherry tomato seedlings'), _listing(2, 'Basil pots')],
    // Also nearby — shown once, not twice.
    fromFollowing: [
      _listing(2, 'Basil pots'),
      _listing(7, 'Heirloom chilli plants'),
    ],
  );

Future<ProviderContainer> _pumpHome(
  WidgetTester tester,
  FakeApiClient fakeClient,
) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  fakeClient.meResult = buildFakeUser(id: 1, name: 'Me');

  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(fakeClient),
      secureStorageProvider.overrideWithValue(fakeStorage),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeFeedScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.dragUntilVisible(
    finder,
    find.byType(CustomScrollView),
    const Offset(0, -150),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the greeting, search bar and quick access, with no feed', (
    tester,
  ) async {
    await _pumpHome(tester, FakeApiClient());

    // No growing setup or town on the fake user, so the slogan shows.
    expect(find.text('Grow. Share. Sustain.'), findsOneWidget);
    expect(find.text('Search items, people, places'), findsOneWidget);
    expect(find.text('What to grow now'), findsOneWidget);
    expect(find.text('Weather'), findsOneWidget);
    expect(find.text('Community'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Marketplace'), findsOneWidget);
    // Log out lives on the Profile page now, not next to the bell.
    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.textContaining('Community Feed'), findsNothing);
  });

  testWidgets('quick access opens the matching tab', (tester) async {
    final container = await _pumpHome(tester, FakeApiClient());

    await tester.tap(find.byKey(const Key('quick-access-community')));
    expect(container.read(selectedTabIndexProvider), 1);

    await tester.tap(find.byKey(const Key('quick-access-events')));
    expect(container.read(selectedTabIndexProvider), 2);

    await tester.tap(find.byKey(const Key('quick-access-marketplace')));
    expect(container.read(selectedTabIndexProvider), 3);
  });

  testWidgets('quick access opens the sowing guide and the weather', (
    tester,
  ) async {
    await _pumpHome(tester, FakeApiClient());

    await tester.tap(find.byKey(const Key('quick-access-grow-now')));
    await tester.pumpAndSettle();
    expect(find.byType(GrowNowScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick-access-weather')));
    await tester.pumpAndSettle();
    expect(find.byType(WeatherScreen), findsOneWidget);
  });

  testWidgets('searching opens results for items, members and groups', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..searchResult = SearchResults(
        listings: [_listing(3, 'Tomato seedlings')],
        members: [buildFakeUser(id: 8, name: 'Tomato Tom')],
        groups: [
          Group(
            id: 4,
            name: 'Tomato Growers',
            slug: 'tomato-growers',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
      );
    await _pumpHome(tester, fakeClient);

    await tester.tap(find.byKey(const Key('home-search-field')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('search-screen-field')),
      'tomato',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(fakeClient.searchedTerms, ['tomato']);
    expect(find.byType(SearchResultsScreen), findsOneWidget);
    expect(find.text('Tomato seedlings'), findsOneWidget);
    for (final key in ['search-member-8', 'search-group-4']) {
      await tester.dragUntilVisible(
        find.byKey(Key(key)),
        find.byType(CustomScrollView),
        const Offset(0, -150),
      );
      expect(find.byKey(Key(key)), findsOneWidget);
    }
  });

  testWidgets('typing suggests terms, items, people and groups live', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..suggestionsResult = SearchSuggestions(
        terms: const [
          SearchSuggestion(
            text: 'tomato plants',
            type: SearchSuggestionType.history,
          ),
          SearchSuggestion(text: 'Tottenham', type: SearchSuggestionType.place),
        ],
        results: SearchResults(
          listings: [_listing(3, 'Tomato seedlings')],
          members: [buildFakeUser(id: 8, name: 'Tomato Tom')],
          groups: [
            Group(
              id: 4,
              name: 'Tomato Growers',
              slug: 'tomato-growers',
              createdAt: DateTime(2026, 1, 1),
            ),
          ],
        ),
      );
    await _pumpHome(tester, fakeClient);
    await tester.tap(find.byKey(const Key('home-search-field')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-screen-field')), 't');
    await tester.enterText(find.byKey(const Key('search-screen-field')), 'to');
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // Only the last keystroke is fetched, and nothing is saved as a search.
    expect(fakeClient.suggestedTerms, ['to']);
    expect(fakeClient.searchedTerms, isEmpty);
    for (final key in [
      'search-submit-row',
      'search-suggestion-tomato plants',
      'search-suggestion-Tottenham',
      'search-suggest-listing-3',
      'search-suggest-member-8',
      'search-suggest-group-4',
    ]) {
      await tester.dragUntilVisible(
        find.byKey(Key(key)),
        find.byType(ListView).last,
        const Offset(0, -100),
      );
      expect(find.byKey(Key(key)), findsOneWidget);
    }

    await tester.dragUntilVisible(
      find.byKey(const Key('search-suggestion-Tottenham')),
      find.byType(ListView).last,
      const Offset(0, 100),
    );
    await tester.tap(find.byKey(const Key('search-suggestion-Tottenham')));
    await tester.pumpAndSettle();

    expect(fakeClient.searchedTerms, ['Tottenham']);
    expect(find.byType(SearchResultsScreen), findsOneWidget);
  });

  testWidgets('the search screen lists recent searches before typing', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()..searchHistoryResult = ['basil'];
    await _pumpHome(tester, fakeClient);
    await tester.tap(find.byKey(const Key('home-search-field')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-recent-basil')), findsOneWidget);

    await tester.tap(find.byKey(const Key('search-clear-history')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-recent-basil')), findsNothing);
  });

  testWidgets('recent searches show as chips that search again', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()..searchHistoryResult = ['basil'];
    await _pumpHome(tester, fakeClient);

    await tester.tap(find.byKey(const Key('recent-search-basil')));
    await tester.pumpAndSettle();

    expect(fakeClient.searchedTerms, ['basil']);
  });

  testWidgets('matches for past searches come first in picked for you', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..feedMarketplaceResult = FeedMarketplace(
        nearby: [_listing(1, 'Cherry tomato seedlings')],
        forYou: [_listing(9, 'Chilli plants')],
      );
    await _pumpHome(tester, fakeClient);
    await _scrollTo(tester, find.byKey(const Key('listing-card-1')));

    expect(
      tester.getTopLeft(find.byKey(const Key('listing-card-9'))).dx,
      lessThan(tester.getTopLeft(find.byKey(const Key('listing-card-1'))).dx),
    );
  });

  testWidgets('picked for you shows nearby and followed listings once each', (
    tester,
  ) async {
    await _pumpHome(tester, _clientWithListings());

    await _scrollTo(tester, find.byKey(const Key('listing-card-7')));
    expect(find.text('Cherry tomato seedlings'), findsOneWidget);
    expect(find.text('Basil pots'), findsOneWidget);
    expect(find.text('Heirloom chilli plants'), findsOneWidget);
  });

  testWidgets('saving a picked listing saves it for real', (tester) async {
    final fakeClient = _clientWithListings();
    await _pumpHome(tester, fakeClient);

    await _scrollTo(tester, find.byKey(const Key('listing-save-1')));
    await tester.tap(find.byKey(const Key('listing-save-1')));
    await tester.pumpAndSettle();

    expect(fakeClient.savedListingIds, [1]);
  });

  testWidgets('with nothing nearby it says so', (tester) async {
    await _pumpHome(tester, FakeApiClient());
    await _scrollTo(tester, find.text('Nothing near you yet'));

    expect(find.text('Nothing near you yet'), findsOneWidget);
  });

  testWidgets('picked for you shows at most six, with See all', (tester) async {
    final fakeClient = FakeApiClient()
      ..feedMarketplaceResult = FeedMarketplace(
        nearby: [for (var i = 1; i <= 9; i++) _listing(i, 'Item $i')],
      );
    final container = await _pumpHome(tester, fakeClient);

    await _scrollTo(tester, find.byKey(const Key('listing-card-6')));
    expect(find.byKey(const Key('listing-card-7')), findsNothing);

    await tester.dragUntilVisible(
      find.byKey(const Key('picked-for-you-see-all')),
      find.byType(CustomScrollView),
      const Offset(0, 150),
    );
    await tester.tap(find.byKey(const Key('picked-for-you-see-all')));
    expect(container.read(selectedTabIndexProvider), 3);
  });
}
