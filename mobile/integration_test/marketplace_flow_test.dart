import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shobuj_mobile/main.dart' as app;
import 'package:shobuj_mobile/screens/discovery/widgets/listing_grid_card.dart';

/// Taps through the Marketplace in the real app against the live server,
/// signed in as whoever is on the device. Read-only: the Sell/Swap forms
/// are only checked for their validation, never submitted.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int ms = 2500]) async {
    for (var i = 0; i < ms ~/ 250; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> back(WidgetTester tester) async {
    final NavigatorState nav = tester.state(find.byType(Navigator).last);
    nav.pop();
    await settle(tester, 1200);
  }

  testWidgets('marketplace end to end (read-only)', (tester) async {
    final log = <String>[];
    void ok(String step) {
      log.add('OK  $step');
      // ignore: avoid_print
      print('E2E-UI OK  $step');
    }

    app.main();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(NavigationBar).evaluate().isNotEmpty) break;
    }
    expect(find.byType(NavigationBar), findsOneWidget);
    ok('app opens signed in');

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Marketplace'),
      ),
    );
    await settle(tester, 4000);
    expect(find.text('Listings near you'), findsOneWidget);
    expect(find.byType(ListingGridCard), findsWidgets);
    ok('Marketplace tab shows the listing grid');

    // Buy narrows to items for sale, and back.
    await tester.tap(find.byKey(const Key('marketplace-buy')));
    await settle(tester, 3000);
    expect(find.byType(ListingGridCard), findsWidgets);
    expect(
      find.text('Swap'),
      findsOneWidget,
    ); // only the action tile, no "Swap" price labels
    ok('Buy shows only items for sale');
    await tester.tap(find.byKey(const Key('marketplace-buy')));
    await settle(tester, 3000);

    // Filters sheet: choose a category, apply, then clear.
    await tester.tap(find.byKey(const Key('discovery-filter-button')));
    await settle(tester, 1200);
    expect(find.text('Filters'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Seed'),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('filter-apply')));
    await settle(tester, 3000);
    ok('Filters: category applied');
    await tester.tap(find.byKey(const Key('discovery-filter-button')));
    await settle(tester, 1200);
    await tester.tap(find.byKey(const Key('filter-clear-all')));
    await tester.tap(find.byKey(const Key('filter-apply')));
    await settle(tester, 3000);
    ok('Filters: cleared');

    // Search.
    await tester.enterText(find.byType(TextField).first, 'DEMO');
    await settle(tester, 3000);
    expect(find.byType(ListingGridCard), findsWidgets);
    ok('search "DEMO" finds the demo listings');
    await tester.enterText(find.byType(TextField).first, '');
    await settle(tester, 3000);

    // Open a listing.
    await tester.tap(find.byType(ListingGridCard).first);
    await settle(tester, 3000);
    final ownBar = find.byKey(const Key('owner-edit')).evaluate().isNotEmpty;
    expect(
      ownBar || find.byKey(const Key('listing-cta')).evaluate().isNotEmpty,
      isTrue,
    );
    ok(
      ownBar
          ? 'listing page shows seller tools (own listing)'
          : 'listing page shows Message Seller',
    );
    await back(tester);

    // Sell form validation.
    await tester.tap(find.byKey(const Key('marketplace-sell')));
    await settle(tester, 2000);
    expect(find.text('Sell an Item'), findsOneWidget);
    final submit = find.byKey(const Key('create-listing-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await settle(tester, 800);
    expect(find.text('Enter a title.'), findsOneWidget);
    expect(find.text('Add at least one photo.'), findsOneWidget);
    ok('Sell form opens and blocks an empty post');
    await back(tester);

    // Swap form.
    await tester.tap(find.byKey(const Key('marketplace-swap')));
    await settle(tester, 2000);
    expect(find.text('Swap an Item'), findsOneWidget);
    expect(find.text('Exchange with another item'), findsOneWidget);
    ok('Swap form opens');
    await back(tester);

    // Favorites and Messages from the header.
    await tester.tap(find.byTooltip('Favorites').first);
    await settle(tester, 2500);
    expect(find.text('Favorites'), findsWidgets);
    ok('Favorites opens');
    await back(tester);

    await tester.tap(find.byTooltip('Messages').first);
    await settle(tester, 3000);
    expect(find.text('Marketplace Messages'), findsOneWidget);
    ok('Messages opens');
    final chats = find.byKey(const Key('deal-bar'));
    if (find.textContaining('made an offer').evaluate().isNotEmpty) {
      await tester.tap(find.textContaining('made an offer').first);
      await settle(tester, 3000);
      expect(chats, findsOneWidget);
      ok('a chat opens with its deal bar');
    }

    // ignore: avoid_print
    print('E2E-UI DONE ${log.length} steps');
  });
}
