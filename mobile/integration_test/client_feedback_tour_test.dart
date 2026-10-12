import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shobuj_mobile/main.dart' as app;
import 'package:shobuj_mobile/screens/events/widgets/event_list_tile.dart';

/// Walks the screens changed for the 2026-10-12 client feedback in the real
/// app against the live server, signed in as whoever is on the device.
/// Read-only: nothing is submitted. Prints `SHOT <name>` and holds each
/// screen so a simulator screenshot can be taken from outside.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int ms = 2500]) async {
    for (var i = 0; i < ms ~/ 250; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    // ignore: avoid_print
    print('SHOT $name');
    await settle(tester, 3000);
  }

  Future<void> back(WidgetTester tester) async {
    final NavigatorState nav = tester.state(find.byType(Navigator).last);
    nav.pop();
    await settle(tester, 1500);
  }

  Future<void> tab(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      ),
    );
    await settle(tester, 3500);
  }

  testWidgets('client feedback tour (read-only)', (tester) async {
    app.main();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byType(NavigationBar).evaluate().isNotEmpty) break;
    }
    await settle(tester, 3000);

    // 8. Slogan under the greeting.
    expect(find.text('Grow. Share. Sustain.'), findsOneWidget);
    await shot(tester, '01-home-slogan');

    // 9. My Listings rows open the listing.
    await tester.tap(find.byKey(const Key('profile-avatar-button')));
    await settle(tester, 3500);
    await tester.tap(find.text('My Listings').first);
    await settle(tester, 3000);
    await shot(tester, '02-my-listings');
    final rows = find.byType(InkWell).hitTestable();
    final manage = find.text('Manage');
    if (manage.evaluate().isNotEmpty) {
      final firstRow = find
          .ancestor(of: manage.first, matching: find.byType(InkWell))
          .first;
      await tester.tapAt(tester.getTopLeft(firstRow) + const Offset(120, 30));
      await settle(tester, 3500);
      await shot(tester, '03-listing-opened-from-my-listings');
      await back(tester);
    } else {
      // ignore: avoid_print
      print('NOTE no listings on this account (${rows.evaluate().length})');
    }
    await back(tester);

    // 15. Marketplace filter categories.
    await tab(tester, 'Marketplace');
    await tester.tap(find.byKey(const Key('discovery-filter-button')));
    await settle(tester, 2000);
    await shot(tester, '04-marketplace-filters');
    expect(find.text('Seed'), findsWidgets);
    expect(find.text('Live plants'), findsWidgets);
    await back(tester);

    // 12. End time on the create form (not submitted).
    await tab(tester, 'Events');
    await tester.tap(find.byKey(const Key('host-event-button')));
    await settle(tester, 2500);
    await tester.scrollUntilVisible(
      find.byKey(const Key('event-end-time')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, 800);
    await shot(tester, '05-create-event-end-time');
    await back(tester);

    // 13. Edit a hosted event (opened, not saved).
    await tester.tap(find.byKey(const Key('events-tab-mine')));
    await settle(tester, 3500);
    final hosting = find.descendant(
      of: find.byKey(const Key('my-events-hosting')),
      matching: find.byType(EventListTile),
    );
    if (hosting.evaluate().isNotEmpty) {
      await tester.tap(hosting.first);
      await settle(tester, 3500);
      await shot(tester, '06-hosted-event-with-edit');
      await tester.tap(find.byKey(const Key('event-edit-button')));
      await settle(tester, 2500);
      await shot(tester, '07-edit-event');
      await back(tester);
      await back(tester);
    } else {
      // ignore: avoid_print
      print('NOTE this account hosts no published events');
    }
  });
}
