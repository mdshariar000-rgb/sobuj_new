import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/event.dart';
import 'package:shobuj_mobile/models/event_enums.dart';
import 'package:shobuj_mobile/models/event_review.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/profile/address_screen.dart';
import 'package:shobuj_mobile/screens/auth/auth_gate.dart';
import 'package:shobuj_mobile/models/uk_address.dart';
import 'package:shobuj_mobile/screens/auth/forgot_password_screen.dart';
import 'package:shobuj_mobile/screens/events/create_event_screen.dart';
import 'package:shobuj_mobile/screens/events/event_detail_screen.dart';
import 'package:shobuj_mobile/screens/events/events_screen.dart';
import 'package:shobuj_mobile/screens/groups/group_chat_screen.dart';
import 'package:shobuj_mobile/screens/groups/groups_screen.dart';
import 'package:shobuj_mobile/services/api_exception.dart';

import 'package:shobuj_mobile/theme/app_theme.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';
import '../support/fake_uk_location_service.dart';

Event _event({
  int id = 5,
  EventStatus status = EventStatus.published,
  double? fee,
  List<DateTime> proposedDates = const [],
  DateTime? endsAt,
  int hostId = 2,
}) => Event(
  id: id,
  title: 'Seed swap',
  format: EventFormat.inPerson,
  startsAt: DateTime(2026, 11, 7, 10),
  endsAt: endsAt,
  status: status,
  registrationFee: fee,
  proposedDates: proposedDates,
  location: 'Leeds Library',
  host: buildFakeUser(id: hostId, name: 'Rina'),
  createdAt: DateTime(2026, 10, 1),
);

Future<void> _pump(
  WidgetTester tester,
  FakeApiClient fakeClient,
  Widget home,
) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  fakeClient.meResult ??= buildFakeUser(id: 1, name: 'Me');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
      // The real theme, so layout bugs it causes (e.g. full-width buttons
      // in a Row) show up here too.
      child: MaterialApp(theme: AppTheme.light(), home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('forgot password', () {
    testWidgets('sends a code, then resets with it', (tester) async {
      final fakeClient = FakeApiClient();
      await _pump(
        tester,
        fakeClient,
        const ForgotPasswordScreen(initialEmail: 'rina@example.com'),
      );

      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();
      expect(fakeClient.passwordResetCodeEmails, ['rina@example.com']);

      await tester.enterText(
        find.byKey(const Key('reset-code-field')),
        '123456',
      );
      await tester.enterText(
        find.byKey(const Key('reset-password-field')),
        'brand-new-pass',
      );
      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();

      expect(fakeClient.lastPasswordReset?.code, '123456');
      expect(fakeClient.lastPasswordReset?.password, 'brand-new-pass');
    });

    testWidgets('a wrong code shows the server message', (tester) async {
      final fakeClient = FakeApiClient()
        ..resetPasswordError = const ApiException(
          message: 'That code is wrong or has expired. Ask for a new one.',
          statusCode: 422,
        );
      await _pump(
        tester,
        fakeClient,
        const ForgotPasswordScreen(initialEmail: 'rina@example.com'),
      );
      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('reset-code-field')),
        '000000',
      );
      await tester.enterText(
        find.byKey(const Key('reset-password-field')),
        'brand-new-pass',
      );
      await tester.tap(find.byKey(const Key('reset-submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('wrong or has expired'), findsOneWidget);
    });
  });

  testWidgets('requesting a group sends it to the admins', (tester) async {
    final fakeClient = FakeApiClient()
      ..groupsResult = const PaginatedResponse(
        data: [],
        currentPage: 1,
        lastPage: 1,
        total: 0,
      );
    await _pump(tester, fakeClient, const GroupsScreen());
    // "Request a group" sits at the end of the Discover tab.
    await tester.tap(find.byKey(const Key('groups-tab-discover')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('request-group-button')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('request-group-name')),
      'Junior Ambassadors',
    );
    await tester.tap(find.byKey(const Key('request-group-submit')));
    await tester.pumpAndSettle();

    expect(fakeClient.groupRequests.single.name, 'Junior Ambassadors');
    expect(find.textContaining('review your group request'), findsOneWidget);
  });

  group('events', () {
    testWidgets('the detail shows the fee and proposed dates', (tester) async {
      final event = _event(
        fee: 3.5,
        proposedDates: [DateTime(2026, 11, 14, 10)],
      );
      await _pump(
        tester,
        FakeApiClient()..eventResult = event,
        EventDetailScreen(event: event),
      );

      expect(find.byKey(const Key('event-fee-label')), findsOneWidget);
      expect(find.textContaining('£3.50'), findsNWidgets(2));
      expect(find.text('Also proposed:'), findsOneWidget);
    });

    testWidgets('a review can be posted and the author can delete it', (
      tester,
    ) async {
      final fakeClient = FakeApiClient()..eventResult = _event();
      await _pump(tester, fakeClient, EventDetailScreen(event: _event()));

      await tester.scrollUntilVisible(
        find.byKey(const Key('review-submit')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const Key('review-star-4')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('review-star-4')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('review-body-field')),
        'Lovely day',
      );
      await tester.tap(find.byKey(const Key('review-submit')));
      await tester.pumpAndSettle();

      expect(fakeClient.reviewsPosted.single.rating, 4);
      expect(fakeClient.reviewsPosted.single.body, 'Lovely day');
      expect(find.text('Lovely day'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete'));
      await tester.pumpAndSettle();
      expect(fakeClient.deletedEventReviewIds, [101]);
    });

    testWidgets("someone else's review can be reported", (tester) async {
      final fakeClient = FakeApiClient()
        ..eventResult = _event()
        ..eventReviewsResult = [
          EventReview(
            id: 7,
            eventId: 5,
            body: 'Can I bring seeds?',
            user: buildFakeUser(id: 3, name: 'Karim'),
            createdAt: DateTime.now(),
          ),
        ];
      await _pump(tester, fakeClient, EventDetailScreen(event: _event()));
      await tester.scrollUntilVisible(
        find.byKey(const Key('event-review-7')),
        200,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('event-review-7')),
          matching: find.byKey(const Key('user-safety-menu')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('drafts get no reviews section', (tester) async {
      final draft = _event(status: EventStatus.draft);
      await _pump(
        tester,
        FakeApiClient()..eventResult = draft,
        EventDetailScreen(event: draft),
      );

      expect(find.text('Reviews & Comments'), findsNothing);
    });

    testWidgets('a draft from My events opens to publish it', (tester) async {
      final draft = _event(
        id: 12,
        status: EventStatus.draft,
        fee: 2,
        endsAt: DateTime(2026, 11, 7, 12),
      );
      final fakeClient = FakeApiClient()
        ..myDraftsResult = [draft]
        ..createEventResult = _event(id: 12);
      await _pump(tester, fakeClient, const EventsScreen());
      await tester.tap(find.byKey(const Key('events-tab-mine')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('event-tile-12')));
      await tester.pumpAndSettle();
      expect(find.byType(CreateEventScreen), findsOneWidget);
      expect(find.text('Edit Event'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('event-fee-field')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('event-fee-field')))
            .controller
            ?.text,
        '2.00',
      );

      await tester.tap(find.text('Publish Event'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastUpdatedEventId, 12);
      expect(fakeClient.lastUpdatedEventStatus, EventStatus.published);
    });

    testWidgets('an event needs an end time to be published', (tester) async {
      final draft = _event(id: 12, status: EventStatus.draft);
      final fakeClient = FakeApiClient()..createEventResult = _event(id: 12);
      await _pump(tester, fakeClient, CreateEventScreen(event: draft));

      await tester.tap(find.text('Publish Event'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastUpdatedEventId, isNull);
      await tester.scrollUntilVisible(
        find.text('Pick an end time for the event.'),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Pick an end time for the event.'), findsOneWidget);
    });

    testWidgets('the host can edit a published event in place', (tester) async {
      final event = _event(hostId: 1, endsAt: DateTime(2026, 11, 7, 12));
      final fakeClient = FakeApiClient()
        ..eventResult = event
        ..createEventResult = event;
      await _pump(tester, fakeClient, EventDetailScreen(event: event));

      await tester.tap(find.byKey(const Key('event-edit-button')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Event'), findsOneWidget);
      expect(find.text('Save Draft'), findsNothing);

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastUpdatedEventId, 5);
      expect(fakeClient.lastUpdatedEventStatus, EventStatus.published);
      // Times go back exactly as entered — no time-zone shift.
      expect(fakeClient.lastUpdatedEventStartsAt, DateTime(2026, 11, 7, 10));
      expect(fakeClient.lastUpdatedEventEndsAt, DateTime(2026, 11, 7, 12));
    });

    testWidgets('only the host sees the edit button', (tester) async {
      final event = _event();
      final fakeClient = FakeApiClient()..eventResult = event;
      await _pump(tester, fakeClient, EventDetailScreen(event: event));

      expect(find.byKey(const Key('event-edit-button')), findsNothing);
    });
  });

  group('event chat', () {
    testWidgets('going attendees can open the event chat', (tester) async {
      final event = Event(
        id: 5,
        title: 'Seed swap',
        format: EventFormat.inPerson,
        startsAt: DateTime(2026, 11, 7, 10),
        status: EventStatus.published,
        myRsvpStatus: EventAttendeeStatus.going,
        host: buildFakeUser(id: 2, name: 'Rina'),
        createdAt: DateTime(2026, 10, 1),
      );
      final fakeClient = FakeApiClient()
        ..eventResult = event
        ..eventChatResult = Group(
          id: 40,
          name: 'Seed swap',
          slug: 'event-5-chat',
          isMember: true,
          createdAt: DateTime(2026, 10, 1),
        );
      await _pump(tester, fakeClient, EventDetailScreen(event: event));

      await tester.ensureVisible(find.byKey(const Key('open-event-chat')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-event-chat')));
      await tester.pumpAndSettle();

      expect(find.byType(GroupChatScreen), findsOneWidget);
    });

    testWidgets('people not going are told to RSVP first', (tester) async {
      final event = _event();
      await _pump(
        tester,
        FakeApiClient()..eventResult = event,
        EventDetailScreen(event: event),
      );

      expect(find.byKey(const Key('open-event-chat')), findsNothing);
      expect(
        find.text('RSVP as going to join the conversation.'),
        findsOneWidget,
      );
    });

    testWidgets('the bottom bar chat button opens the event chat', (
      tester,
    ) async {
      final event = Event(
        id: 5,
        title: 'Seed swap',
        format: EventFormat.inPerson,
        startsAt: DateTime(2026, 11, 7, 10),
        status: EventStatus.published,
        myRsvpStatus: EventAttendeeStatus.going,
        host: buildFakeUser(id: 2, name: 'Rina'),
        createdAt: DateTime(2026, 10, 1),
      );
      final fakeClient = FakeApiClient()
        ..eventResult = event
        ..eventChatResult = Group(
          id: 40,
          name: 'Seed swap',
          slug: 'event-5-chat',
          isMember: true,
          createdAt: DateTime(2026, 10, 1),
        );
      await _pump(tester, fakeClient, EventDetailScreen(event: event));

      // No scrolling needed — it sits in the sticky bottom bar.
      await tester.tap(find.byKey(const Key('event-bottom-chat-button')));
      await tester.pumpAndSettle();

      expect(find.byType(GroupChatScreen), findsOneWidget);
    });

    testWidgets('the bottom bar chat button asks non-attendees to RSVP', (
      tester,
    ) async {
      final event = _event();
      await _pump(
        tester,
        FakeApiClient()..eventResult = event,
        EventDetailScreen(event: event),
      );

      await tester.tap(find.byKey(const Key('event-bottom-chat-button')));
      await tester.pump();

      expect(find.byType(GroupChatScreen), findsNothing);
      expect(
        find.text('RSVP as going to join this event’s chat.'),
        findsOneWidget,
      );
    });

    testWidgets('the host can open the chat without an RSVP', (tester) async {
      final event = _event();
      await _pump(
        tester,
        FakeApiClient()
          ..meResult = buildFakeUser(id: 2, name: 'Rina')
          ..eventResult = event,
        EventDetailScreen(event: event),
      );

      expect(find.byKey(const Key('open-event-chat')), findsOneWidget);
    });
  });

  group('address', () {
    Future<void> pumpGate(WidgetTester tester, FakeApiClient client) async {
      final fakeStorage = FakeSecureStorageService();
      await fakeStorage.saveToken('existing-token');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(client),
            secureStorageProvider.overrideWithValue(fakeStorage),
            ukLocationServiceProvider.overrideWithValue(
              FakeUkLocationService(),
            ),
          ],
          child: const MaterialApp(home: AuthGate()),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an account without an address must add one first', (
      tester,
    ) async {
      final fakeClient = FakeApiClient()
        ..meResult = buildFakeUser().copyWith(needsAddress: true)
        ..updateProfileResult = buildFakeUser().copyWith(
          needsAddress: false,
          address: const UkAddress(
            line1: '12 Cardigan Road',
            city: 'Leeds',
            postcode: 'LS6 3AA',
          ),
        );
      await pumpGate(tester, fakeClient);

      expect(find.byType(AddressScreen), findsOneWidget);
      expect(find.text('Complete your address'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('address-postcode-field')),
        'ls6 3aa',
      );
      await tester.tap(find.byKey(const Key('address-find-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('address-line1-field')),
        '12 Cardigan Road',
      );
      await tester.enterText(
        find.byKey(const Key('address-city-field')),
        'Leeds',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('address-save')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('address-save')));
      await tester.pumpAndSettle();

      final sent = fakeClient.lastUpdateProfileArgs!;
      expect((sent['address'] as UkAddress).postcode, 'LS6 3AA');
      expect(sent['latitude'], 53.8173);
      expect(sent['locationLabel'], 'Headingley, Leeds, England');
      expect(find.byType(AddressScreen), findsNothing);
    });

    testWidgets('an account with an address goes straight in', (tester) async {
      await pumpGate(tester, FakeApiClient()..meResult = buildFakeUser());

      expect(find.byType(AddressScreen), findsNothing);
    });

    testWidgets('without postcode lookups, Find fills in the town and asks '
        'for the street', (tester) async {
      await pumpGate(
        tester,
        FakeApiClient()
          ..meResult = buildFakeUser().copyWith(needsAddress: true),
      );

      await tester.enterText(
        find.byKey(const Key('address-postcode-field')),
        'cf10 1aa',
      );
      await tester.tap(find.byKey(const Key('address-find-button')));
      await tester.pumpAndSettle();

      expect(find.text('Enter your house number and street.'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('address-city-field')))
            .controller
            ?.text,
        'Cardiff',
      );
    });

    testWidgets('only the postcode is typed: picking from the list fills in '
        'the whole address', (tester) async {
      final fakeClient = FakeApiClient()
        ..meResult = buildFakeUser().copyWith(needsAddress: true)
        ..updateProfileResult = buildFakeUser()
        ..postcodeAddressesResult = const [
          AddressSuggestion(
            id: 'paf_1',
            address: 'Flat 2, 12 Cardigan Road, Leeds, LS6 3AA',
            line1: 'Flat 2',
            line2: '12 Cardigan Road',
            city: 'Leeds',
            county: 'West Yorkshire',
            postcode: 'LS6 3AA',
          ),
          AddressSuggestion(
            id: 'paf_2',
            address: '14 Cardigan Road, Leeds, LS6 3AA',
            line1: '14 Cardigan Road',
            city: 'Leeds',
            county: 'West Yorkshire',
            postcode: 'LS6 3AA',
          ),
        ];
      await pumpGate(tester, fakeClient);

      expect(find.byKey(const Key('address-line1-field')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('address-postcode-field')),
        'ls6 3aa',
      );
      await tester.tap(find.byKey(const Key('address-find-button')));
      await tester.pumpAndSettle();
      expect(fakeClient.lastPostcodeLookup, 'LS6 3AA');

      await tester.tap(find.byKey(const Key('address-result-paf_1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('address-summary')), findsOneWidget);
      expect(find.text('Flat 2, 12 Cardigan Road'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('address-save')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('address-save')));
      await tester.pumpAndSettle();

      final sent = fakeClient.lastUpdateProfileArgs!['address'] as UkAddress;
      expect(sent.line1, 'Flat 2');
      expect(sent.line2, '12 Cardigan Road');
      expect(sent.city, 'Leeds');
      expect(sent.county, 'West Yorkshire');
      expect(sent.postcode, 'LS6 3AA');
    });

    testWidgets('an address must be chosen before saving', (tester) async {
      final fakeClient = FakeApiClient()
        ..meResult = buildFakeUser().copyWith(needsAddress: true)
        ..postcodeAddressesResult = const [
          AddressSuggestion(
            id: 'paf_2',
            address: '14 Cardigan Road, Leeds, LS6 3AA',
            line1: '14 Cardigan Road',
            city: 'Leeds',
            postcode: 'LS6 3AA',
          ),
        ];
      await pumpGate(tester, fakeClient);

      await tester.enterText(
        find.byKey(const Key('address-postcode-field')),
        'ls6 3aa',
      );
      await tester.tap(find.byKey(const Key('address-find-button')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('address-save')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('address-save')));
      await tester.pumpAndSettle();

      expect(fakeClient.lastUpdateProfileArgs, isNull);
      expect(find.text('Choose your address from the list.'), findsOneWidget);
    });

    testWidgets("an unknown postcode says so", (tester) async {
      await pumpGate(
        tester,
        FakeApiClient()
          ..meResult = buildFakeUser().copyWith(needsAddress: true)
          ..postcodeAddressesError = const ApiException(
            message: "We couldn't find that postcode. Please check it.",
            statusCode: 404,
          ),
      );

      await tester.enterText(
        find.byKey(const Key('address-postcode-field')),
        'ls99 9zz',
      );
      await tester.tap(find.byKey(const Key('address-find-button')));
      await tester.pumpAndSettle();

      expect(
        find.text("We couldn't find that postcode. Please check it."),
        findsOneWidget,
      );
      expect(find.byKey(const Key('address-line1-field')), findsNothing);
    });

    testWidgets("\"My address isn't listed\" opens the lines to type", (
      tester,
    ) async {
      await pumpGate(
        tester,
        FakeApiClient()
          ..meResult = buildFakeUser().copyWith(needsAddress: true)
          ..postcodeAddressesResult = const [
            AddressSuggestion(
              id: 'paf_2',
              address: '14 Cardigan Road, Leeds, LS6 3AA',
              line1: '14 Cardigan Road',
              city: 'Leeds',
              postcode: 'LS6 3AA',
            ),
          ],
      );

      await tester.enterText(
        find.byKey(const Key('address-postcode-field')),
        'ls6 3aa',
      );
      await tester.tap(find.byKey(const Key('address-find-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text("My address isn't listed"));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('address-line1-field')), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('address-city-field')))
            .controller
            ?.text,
        'Leeds',
      );
    });

    testWidgets("a server that ignores the address doesn't claim success", (
      tester,
    ) async {
      final fakeClient = FakeApiClient()
        ..meResult = buildFakeUser().copyWith(needsAddress: true)
        // An older server: answers OK but without the address.
        ..updateProfileResult = buildFakeUser().copyWith(needsAddress: true);
      await pumpGate(tester, fakeClient);

      await tester.enterText(
        find.byKey(const Key('address-postcode-field')),
        'ls6 3aa',
      );
      await tester.tap(find.byKey(const Key('address-find-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('address-line1-field')),
        '12 Cardigan Road',
      );
      await tester.enterText(
        find.byKey(const Key('address-city-field')),
        'Leeds',
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('address-save')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const Key('address-save')));
      await tester.pumpAndSettle();

      expect(find.textContaining("couldn't be saved"), findsOneWidget);
      expect(find.byType(AddressScreen), findsOneWidget);
    });
  });
}
