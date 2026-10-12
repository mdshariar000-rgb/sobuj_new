import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shobuj_mobile/models/event.dart';
import 'package:shobuj_mobile/models/event_enums.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/events/event_detail_screen.dart';
import 'package:shobuj_mobile/screens/profile/profile_screen.dart';
import 'package:shobuj_mobile/theme/app_theme.dart';

import '../test/support/fake_api_client.dart';
import '../test/support/fake_secure_storage_service.dart';

/// The two feedback screens the device account can't show (it has no
/// listings or hosted events), on the simulator with sample data — no
/// network, nothing saved. Prints `SHOT <name>` for outside screenshots.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int ms = 1500]) async {
    for (var i = 0; i < ms ~/ 250; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    // ignore: avoid_print
    print('SHOT $name');
    await settle(tester, 3000);
  }

  final me = buildFakeUser(id: 1, name: 'Maya');
  final listing = Listing(
    id: 5,
    title: 'Heirloom Tomato Seeds',
    listingType: 'Seed',
    transactionType: TransactionType.sell,
    status: ListingStatus.active,
    price: 4.5,
    viewsCount: 12,
    owner: me,
    createdAt: DateTime(2026, 10, 1),
  );
  final event = Event(
    id: 7,
    title: 'Seed swap at Luton Library',
    description: 'Bring spare seeds to swap.',
    format: EventFormat.inPerson,
    location: 'Luton Library',
    startsAt: DateTime(2026, 11, 7, 10),
    endsAt: DateTime(2026, 11, 7, 12),
    status: EventStatus.published,
    host: me,
    createdAt: DateTime(2026, 10, 1),
  );

  Future<FakeApiClient> pump(WidgetTester tester, Widget home) async {
    final fakeClient = FakeApiClient()
      ..meResult = me
      ..myListingsResult = PaginatedResponse(
        data: [listing],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      )
      ..listingResult = listing
      ..eventResult = event
      ..createEventResult = event;
    final storage = FakeSecureStorageService();
    await storage.saveToken('sample');
    await tester.pumpWidget(
      ProviderScope(
        // A fresh app each time, not the previous screen's navigator.
        key: UniqueKey(),
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          secureStorageProvider.overrideWithValue(storage),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: home),
      ),
    );
    await settle(tester, 2500);
    return fakeClient;
  }

  testWidgets('feedback screens with sample data', (tester) async {
    await pump(tester, const ProfileScreen());
    await tester.tap(find.text('My Listings').first);
    await settle(tester);
    await shot(tester, '02b-my-listings-sample');
    await tester.tap(find.text('Heirloom Tomato Seeds').last);
    await settle(tester, 2500);
    await shot(tester, '03-listing-opened-from-my-listings');

    final fakeClient = await pump(tester, EventDetailScreen(event: event));
    await shot(tester, '06-hosted-event-with-edit');
    await tester.tap(find.byKey(const Key('event-edit-button')));
    await settle(tester, 2000);
    await shot(tester, '07-edit-event');
    await tester.scrollUntilVisible(
      find.byKey(const Key('event-end-time')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await settle(tester, 800);
    await shot(tester, '08-edit-event-times');
    expect(fakeClient.lastUpdatedEventId, isNull);
  });
}
