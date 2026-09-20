import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/event.dart';
import 'package:shobuj_mobile/models/event_enums.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/events/saved_events_screen.dart';

import '../support/fake_api_client.dart';

class SavedEventsFakeApiClient extends FakeApiClient {
  List<Event> saved = const [];
  int? lastUnsavedEventId;

  @override
  Future<PaginatedResponse<Event>> savedEvents({int page = 1}) async {
    return PaginatedResponse(
      data: saved,
      currentPage: 1,
      lastPage: 1,
      total: saved.length,
    );
  }

  @override
  Future<Event> unsaveEvent(int eventId) async {
    lastUnsavedEventId = eventId;
    final event = saved.firstWhere((e) => e.id == eventId);
    return event.copyWith(isSaved: false);
  }
}

Event _buildEvent({required int id, required String title}) {
  return Event(
    id: id,
    title: title,
    format: EventFormat.inPerson,
    startsAt: DateTime(2026, 1, 1),
    status: EventStatus.published,
    isSaved: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  testWidgets('shows saved events', (tester) async {
    final fakeClient = SavedEventsFakeApiClient();
    fakeClient.saved = [_buildEvent(id: 1, title: 'Compost Workshop')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(fakeClient)],
        child: const MaterialApp(home: SavedEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Compost Workshop'), findsOneWidget);
  });

  testWidgets('shows an empty state when nothing is saved', (tester) async {
    final fakeClient = SavedEventsFakeApiClient();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(fakeClient)],
        child: const MaterialApp(home: SavedEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('No saved events yet'), findsOneWidget);
  });

  testWidgets('unsaving an event removes it from the list', (tester) async {
    final fakeClient = SavedEventsFakeApiClient();
    fakeClient.saved = [_buildEvent(id: 1, title: 'Compost Workshop')];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(fakeClient)],
        child: const MaterialApp(home: SavedEventsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.bookmark));
    await tester.pumpAndSettle();

    expect(fakeClient.lastUnsavedEventId, 1);
    expect(find.textContaining('No saved events yet'), findsOneWidget);
  });
}
