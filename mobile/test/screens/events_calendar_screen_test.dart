import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/event.dart';
import 'package:shobuj_mobile/models/event_enums.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/event_providers.dart';
import 'package:shobuj_mobile/screens/events/events_calendar_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Event _buildEvent({
  required int id,
  required String title,
  required DateTime startsAt,
}) {
  return Event(
    id: id,
    title: title,
    format: EventFormat.inPerson,
    startsAt: startsAt,
    status: EventStatus.published,
    attendeesCount: 2,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpCalendar(
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
      child: const MaterialApp(home: EventsCalendarScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens already requesting the real current month from the API', (
    tester,
  ) async {
    final now = DateTime.now();
    final currentMonthKey = monthKey(DateTime(now.year, now.month));

    final fakeClient = FakeApiClient();
    await _pumpCalendar(tester, fakeClient);

    expect(fakeClient.lastEventsMonth, currentMonthKey);
  });

  testWidgets(
    'tapping a day with an event shows it, tapping a day without one shows '
    'the real empty state',
    (tester) async {
      final now = DateTime.now();
      final dayWithEvent = DateTime(now.year, now.month, 15, 10, 0);
      final currentMonthKey = monthKey(DateTime(now.year, now.month));

      final fakeClient = FakeApiClient()
        ..eventsByMonth = {
          currentMonthKey: PaginatedResponse(
            data: [
              _buildEvent(
                id: 1,
                title: 'Compost Workshop',
                startsAt: dayWithEvent,
              ),
            ],
            currentPage: 1,
            lastPage: 1,
            total: 1,
          ),
        };

      await _pumpCalendar(tester, fakeClient);

      await tester.tap(find.byKey(const Key('calendar-day-15')));
      await tester.pumpAndSettle();

      expect(find.text('Compost Workshop'), findsOneWidget);

      await tester.tap(find.byKey(const Key('calendar-day-1')));
      await tester.pumpAndSettle();

      expect(find.text('Compost Workshop'), findsNothing);
      expect(find.textContaining('No events on'), findsOneWidget);
    },
  );

  testWidgets(
    'navigating to the next/previous month re-fetches with that real month',
    (tester) async {
      final now = DateTime.now();
      final nextMonthKey = monthKey(DateTime(now.year, now.month + 1));
      final currentMonthKey = monthKey(DateTime(now.year, now.month));

      final fakeClient = FakeApiClient();
      await _pumpCalendar(tester, fakeClient);

      await tester.tap(find.byKey(const Key('calendar-next-month')));
      await tester.pumpAndSettle();
      expect(fakeClient.lastEventsMonth, nextMonthKey);

      await tester.tap(find.byKey(const Key('calendar-prev-month')));
      await tester.pumpAndSettle();
      expect(fakeClient.lastEventsMonth, currentMonthKey);
    },
  );

  testWidgets('tapping an event in the day list opens its real detail screen', (
    tester,
  ) async {
    final now = DateTime.now();
    final dayWithEvent = DateTime(now.year, now.month, 15, 10, 0);
    final currentMonthKey = monthKey(DateTime(now.year, now.month));

    final fakeClient = FakeApiClient()
      ..eventsByMonth = {
        currentMonthKey: PaginatedResponse(
          data: [
            _buildEvent(
              id: 1,
              title: 'Compost Workshop',
              startsAt: dayWithEvent,
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        ),
      };

    await _pumpCalendar(tester, fakeClient);

    await tester.tap(find.byKey(const Key('calendar-day-15')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Compost Workshop'));
    await tester.pumpAndSettle();

    // The detail screen's real RSVP action only exists there, not on the
    // calendar month view — confirms real navigation happened.
    expect(find.text('RSVP / Register'), findsOneWidget);
  });

  testWidgets(
    'lays out without overflow at a real phone width (not the wider default '
    'test surface)',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final now = DateTime.now();
      final currentMonthKey = monthKey(DateTime(now.year, now.month));
      final fakeClient = FakeApiClient()
        ..eventsByMonth = {
          currentMonthKey: PaginatedResponse(
            data: [
              _buildEvent(
                id: 1,
                title: 'Compost Workshop',
                startsAt: DateTime(now.year, now.month, 15, 10, 0),
              ),
            ],
            currentPage: 1,
            lastPage: 1,
            total: 1,
          ),
        };

      await _pumpCalendar(tester, fakeClient);
      await tester.tap(find.byKey(const Key('calendar-day-15')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );
}
