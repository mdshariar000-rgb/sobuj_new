import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/event.dart';
import 'package:shobuj_mobile/models/event_enums.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/events/events_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Event _buildEvent({
  required int id,
  required String title,
  EventAttendeeStatus? myRsvpStatus,
}) {
  return Event(
    id: id,
    title: title,
    format: EventFormat.inPerson,
    startsAt: DateTime(2026, 6, 1, 18),
    status: EventStatus.published,
    attendeesCount: 3,
    myRsvpStatus: myRsvpStatus,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpEventsScreen(
  WidgetTester tester,
  FakeApiClient fakeClient,
) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  fakeClient.meResult = buildFakeUser(id: 1, name: 'Me');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
      child: const MaterialApp(home: EventsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows events returned by the API', (tester) async {
    final fakeClient = FakeApiClient()
      ..eventsResult = PaginatedResponse(
        data: [
          _buildEvent(id: 1, title: 'Compost Workshop'),
          _buildEvent(
            id: 2,
            title: 'Seed Swap',
            myRsvpStatus: EventAttendeeStatus.going,
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pumpEventsScreen(tester, fakeClient);

    expect(find.text('Compost Workshop'), findsOneWidget);
    expect(find.text('Seed Swap'), findsOneWidget);
    expect(find.text("You're Going"), findsOneWidget);
  });

  testWidgets('shows an empty state when there are no upcoming events', (
    tester,
  ) async {
    await _pumpEventsScreen(tester, FakeApiClient());

    expect(find.text('No upcoming events'), findsOneWidget);
  });

  testWidgets('tapping Host an Event opens the create-event screen', (
    tester,
  ) async {
    await _pumpEventsScreen(tester, FakeApiClient());

    await tester.tap(find.text('Host an Event'));
    await tester.pumpAndSettle();

    expect(find.text('Event Title *'), findsOneWidget);
  });

  testWidgets(
    'has no Upcoming Gatherings header or See Calendar button, and the '
    'header calendar icon opens the real calendar view',
    (tester) async {
      await _pumpEventsScreen(tester, FakeApiClient());

      expect(find.text('Upcoming Gatherings'), findsNothing);
      expect(find.text('See Calendar'), findsNothing);

      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Events Calendar'), findsOneWidget);
    },
  );
}
