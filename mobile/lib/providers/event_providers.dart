import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/event.dart';
import '../models/event_category.dart';
import '../models/event_enums.dart';
import '../services/api_client.dart';
import 'core_providers.dart';

/// The Events tab's filter-chip selection — the real admin-managed
/// category *name* (see [eventCategoriesProvider]), or null (the "All
/// Events" chip) for every category. Real, server-side, via
/// EventController::index()'s `category` handling.
final eventsCategoryProvider = StateProvider<String?>((ref) => null);

/// The admin-managed category list — both the Events tab's filter chips
/// and the "create an event" form's category picker read from this single
/// source of truth rather than each guessing at real values independently.
final eventCategoriesProvider = FutureProvider.autoDispose<List<EventCategory>>(
  (ref) async {
    final apiClient = ref.watch(apiClientProvider);
    return apiClient.eventCategories();
  },
);

@immutable
class EventsListState {
  const EventsListState({
    required this.events,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<Event> events;
  final bool hasMore;
  final bool isLoadingMore;

  EventsListState copyWith({
    List<Event>? events,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return EventsListState(
      events: events ?? this.events,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// The Events & Workshops list — published events, soonest first. Same
/// paginated + optimistic-mutation shape as GroupsListNotifier/
/// HomeFeedNotifier.
class EventsListNotifier extends StateNotifier<AsyncValue<EventsListState>> {
  EventsListNotifier(this._apiClient, this._category)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _apiClient;
  final String? _category;
  int _page = 1;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _apiClient.events(page: 1, category: _category);
      _page = 1;
      return EventsListState(
        events: response.data,
        hasMore: response.hasMorePages,
        isLoadingMore: false,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final response = await _apiClient.events(
        page: _page + 1,
        category: _category,
      );
      _page += 1;
      state = AsyncValue.data(
        current.copyWith(
          events: [...current.events, ...response.data],
          hasMore: response.hasMorePages,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> createEvent({
    int? groupId,
    required String title,
    String? description,
    required EventFormat format,
    String? category,
    File? coverImage,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
    int? capacity,
    required EventStatus status,
  }) async {
    final event = await _apiClient.createEvent(
      groupId: groupId,
      title: title,
      description: description,
      format: format,
      category: category,
      coverImage: coverImage,
      location: location,
      startsAt: startsAt,
      endsAt: endsAt,
      capacity: capacity,
      status: status,
    );
    final current = state.valueOrNull;
    if (current != null && status == EventStatus.published) {
      state = AsyncValue.data(
        current.copyWith(events: [event, ...current.events]),
      );
    }
  }

  Future<void> rsvp(int eventId, EventAttendeeStatus status) async {
    final updated = await _apiClient.rsvpToEvent(eventId, status);
    _replaceEvent(eventId, updated);
  }

  Future<void> cancelRsvp(int eventId) async {
    await _apiClient.cancelEventRsvp(eventId);
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(
        events: current.events.map((event) {
          if (event.id != eventId) return event;
          return event.copyWith(
            clearRsvp: true,
            attendeesCount: (event.attendeesCount ?? 1) - 1,
          );
        }).toList(),
      ),
    );
  }

  /// Toggles optimistically, then reconciles with the server; rolls back on
  /// failure. Real save/unsave — see EventController::save()/unsave().
  Future<void> toggleSaved(Event event) async {
    final wasSaved = event.isSaved ?? false;
    _replaceEvent(event.id, event.copyWith(isSaved: !wasSaved));

    try {
      final updated = wasSaved
          ? await _apiClient.unsaveEvent(event.id)
          : await _apiClient.saveEvent(event.id);
      _replaceEvent(event.id, updated);
    } catch (_) {
      _replaceEvent(event.id, event);
      rethrow;
    }
  }

  void _replaceEvent(int eventId, Event updated) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(
        events: current.events
            .map((event) => event.id == eventId ? updated : event)
            .toList(),
      ),
    );
  }
}

final eventsListProvider =
    StateNotifierProvider.autoDispose<
      EventsListNotifier,
      AsyncValue<EventsListState>
    >(
      (ref) => EventsListNotifier(
        ref.watch(apiClientProvider),
        ref.watch(eventsCategoryProvider),
      ),
    );

/// The "Saved Events" list — every event the user has tapped the bookmark
/// icon on. autoDispose so it's re-fetched fresh each time the screen opens
/// — same pattern as SavedListingsNotifier.
class SavedEventsNotifier extends StateNotifier<AsyncValue<List<Event>>> {
  SavedEventsNotifier(this._apiClient) : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _apiClient;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _apiClient.savedEvents();
      return response.data;
    });
  }

  /// Unsaving here removes the event from this list entirely — this view is
  /// specifically "things I've saved", so an unsaved item doesn't belong in
  /// it anymore. Optimistic, with rollback on failure.
  Future<void> unsave(Event event) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(current.where((e) => e.id != event.id).toList());

    try {
      await _apiClient.unsaveEvent(event.id);
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }
}

final savedEventsProvider =
    StateNotifierProvider.autoDispose<
      SavedEventsNotifier,
      AsyncValue<List<Event>>
    >((ref) => SavedEventsNotifier(ref.watch(apiClientProvider)));

/// Formats a month as the 'YYYY-MM' key EventController::index()'s ?month=
/// filter expects.
String monthKey(DateTime month) =>
    '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

/// Every published event in one calendar month — backs the Events tab's
/// calendar view. Keyed by the first-of-month DateTime so navigating
/// between months (and back again) reuses whatever's already been fetched
/// rather than re-requesting it every time.
final calendarMonthEventsProvider = FutureProvider.autoDispose
    .family<List<Event>, DateTime>((ref, month) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.events(month: monthKey(month));
      return response.data;
    });

/// A single event's own detail — join/leave-equivalent (RSVP) from the
/// detail screen updates this independently of whatever list the user
/// navigated in from, same pattern as GroupDetailNotifier.
class EventDetailNotifier extends StateNotifier<AsyncValue<Event>> {
  EventDetailNotifier(this._apiClient, this._eventId, Event? initial)
    : super(
        initial != null ? AsyncValue.data(initial) : const AsyncValue.loading(),
      ) {
    // Always fetch the full single-event response, even when a cached
    // `initial` (from the list) is already shown — only GET /events/{id}
    // returns attendees_preview and is_saved (see EventController::show()).
    refresh();
  }

  final ApiClient _apiClient;
  final int _eventId;

  Future<void> refresh() async {
    final result = await AsyncValue.guard(() => _apiClient.event(_eventId));
    // A failed background refresh (e.g. transient network error) shouldn't
    // blow away content that's already on screen — only surface the error
    // when there's nothing cached to fall back on.
    if (result.hasError && state.hasValue) return;
    state = result;
  }

  Future<void> rsvp(EventAttendeeStatus status) async {
    final event = await _apiClient.rsvpToEvent(_eventId, status);
    state = AsyncValue.data(event);
  }

  Future<void> cancelRsvp() async {
    await _apiClient.cancelEventRsvp(_eventId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          clearRsvp: true,
          attendeesCount: (current.attendeesCount ?? 1) - 1,
        ),
      );
    }
  }

  /// Toggles optimistically, then reconciles with the server; rolls back on
  /// failure. Real save/unsave — see EventController::save()/unsave().
  Future<void> toggleSaved() async {
    final current = state.valueOrNull;
    if (current == null) return;
    final wasSaved = current.isSaved ?? false;

    state = AsyncValue.data(current.copyWith(isSaved: !wasSaved));
    try {
      final updated = wasSaved
          ? await _apiClient.unsaveEvent(_eventId)
          : await _apiClient.saveEvent(_eventId);
      state = AsyncValue.data(updated);
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }
}

final eventDetailProvider = StateNotifierProvider.autoDispose
    .family<EventDetailNotifier, AsyncValue<Event>, Event>(
      (ref, event) =>
          EventDetailNotifier(ref.watch(apiClientProvider), event.id, event),
    );
