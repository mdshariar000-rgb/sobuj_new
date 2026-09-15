import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/models/event.dart';
import 'package:shobuj_mobile/models/event_enums.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/events/event_detail_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

AppUser _buildHost({
  int id = 9,
  String name = 'Elena Rostova',
  bool isVerified = true,
  String? bio = 'Third-generation citrus grower.',
}) {
  return AppUser(
    id: id,
    name: name,
    isVerified: isVerified,
    bio: bio,
    ratingAvg: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

Event _buildEvent({
  required int id,
  required String title,
  EventAttendeeStatus? myRsvpStatus,
  int attendeesCount = 3,
  int? capacity,
  AppUser? host,
  List<AppUser>? attendeesPreview,
  bool? isSaved,
}) {
  return Event(
    id: id,
    title: title,
    description: 'Bring your own gloves.',
    format: EventFormat.inPerson,
    location: 'Community Garden',
    startsAt: DateTime(2026, 6, 1, 18),
    capacity: capacity,
    status: EventStatus.published,
    attendeesCount: attendeesCount,
    attendeesPreview: attendeesPreview,
    isSaved: isSaved,
    host: host ?? _buildHost(),
    myRsvpStatus: myRsvpStatus,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpEventDetail(
  WidgetTester tester,
  FakeApiClient fakeClient,
  Event event,
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
      child: MaterialApp(home: EventDetailScreen(event: event)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the real event, host, and schedule details', (
    tester,
  ) async {
    final event = _buildEvent(id: 1, title: 'Compost Workshop', capacity: 20);
    await _pumpEventDetail(tester, FakeApiClient(), event);

    expect(find.text('Compost Workshop'), findsOneWidget);
    expect(find.text('Community Garden'), findsOneWidget);
    expect(find.text('Bring your own gloves.'), findsOneWidget);
    expect(find.text('Elena Rostova'), findsOneWidget);
    expect(find.text('Verified Host'), findsOneWidget);
    expect(find.text('IN PERSON'), findsOneWidget);
    // "Free Admission" is real and shown twice on purpose — once as a hero
    // badge, once as the bottom bar's ticket-price value.
    expect(find.text('Free Admission'), findsNWidgets(2));
    expect(find.text('17 Spots Remaining'), findsOneWidget);
  });

  testWidgets('hides the Verified Host pill for an unverified host', (
    tester,
  ) async {
    final event = _buildEvent(
      id: 1,
      title: 'Compost Workshop',
      host: _buildHost(isVerified: false),
    );
    await _pumpEventDetail(tester, FakeApiClient(), event);

    expect(find.text('Verified Host'), findsNothing);
  });

  testWidgets('shows a real attendees preview and a View All sheet', (
    tester,
  ) async {
    final event = _buildEvent(
      id: 1,
      title: 'Compost Workshop',
      attendeesCount: 5,
      attendeesPreview: [
        _buildHost(id: 2, name: 'Carlos Mendoza', bio: null),
        _buildHost(id: 3, name: 'Priya Nair', bio: null),
      ],
    );
    await _pumpEventDetail(tester, FakeApiClient(), event);

    expect(find.text('Growers Attending'), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);

    await tester.ensureVisible(find.text('View All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();

    expect(find.text('Growers Attending · 5'), findsOneWidget);
    expect(find.text('Carlos Mendoza'), findsOneWidget);
    expect(find.text('Priya Nair'), findsOneWidget);
    expect(find.text('+ 3 more registered'), findsOneWidget);
  });

  testWidgets('RSVPing via RSVP / Register calls the API and confirms', (
    tester,
  ) async {
    final event = _buildEvent(id: 1, title: 'Compost Workshop');
    final fakeClient = FakeApiClient()
      ..rsvpToEventResult = _buildEvent(
        id: 1,
        title: 'Compost Workshop',
        myRsvpStatus: EventAttendeeStatus.going,
        attendeesCount: 4,
      );

    await _pumpEventDetail(tester, fakeClient, event);

    await tester.tap(find.widgetWithText(FilledButton, 'RSVP / Register'));
    await tester.pump();

    expect(fakeClient.lastRsvpStatus, EventAttendeeStatus.going);
    expect(find.text('Spot reserved! You’re on the list.'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text("You're Going"), findsOneWidget);
    expect(find.text('Cancel RSVP'), findsOneWidget);
  });

  testWidgets(
    'tapping "Just interested" calls the API with interested',
    (tester) async {
      final event = _buildEvent(id: 1, title: 'Compost Workshop');
      final fakeClient = FakeApiClient()
        ..rsvpToEventResult = _buildEvent(
          id: 1,
          title: 'Compost Workshop',
          myRsvpStatus: EventAttendeeStatus.interested,
        );

      await _pumpEventDetail(tester, fakeClient, event);

      final interestedLink = find.text('Just interested, not going yet?');
      await tester.ensureVisible(interestedLink);
      await tester.pumpAndSettle();
      await tester.tap(interestedLink);
      await tester.pumpAndSettle();

      expect(fakeClient.lastRsvpStatus, EventAttendeeStatus.interested);
      expect(find.text("You're Interested"), findsOneWidget);
    },
  );

  testWidgets('canceling an RSVP calls the API', (tester) async {
    final event = _buildEvent(
      id: 1,
      title: 'Compost Workshop',
      myRsvpStatus: EventAttendeeStatus.interested,
    );

    final fakeClient = FakeApiClient();
    await _pumpEventDetail(tester, fakeClient, event);

    expect(find.text("You're Interested"), findsOneWidget);

    await tester.tap(find.text('Cancel RSVP'));
    await tester.pumpAndSettle();

    expect(fakeClient.cancelEventRsvpCalled, isTrue);
  });

  testWidgets('tapping the bookmark icon saves the event', (tester) async {
    final event = _buildEvent(id: 1, title: 'Compost Workshop', isSaved: false);
    final fakeClient = FakeApiClient()
      ..saveEventResult = _buildEvent(
        id: 1,
        title: 'Compost Workshop',
        isSaved: true,
      );

    await _pumpEventDetail(tester, fakeClient, event);

    await tester.tap(find.byKey(const Key('event-detail-save-button')));
    await tester.pumpAndSettle();

    expect(fakeClient.saveEventCalled, isTrue);
  });

  testWidgets('lays out without overflow at a real phone width', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));

    final event = _buildEvent(
      id: 1,
      title: 'Compost Workshop',
      capacity: 20,
      attendeesCount: 5,
      attendeesPreview: [_buildHost(id: 2, name: 'Carlos Mendoza', bio: null)],
    );
    await _pumpEventDetail(tester, FakeApiClient(), event);

    expect(tester.takeException(), isNull);
  });
}
