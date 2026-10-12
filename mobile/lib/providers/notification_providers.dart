import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_notification.dart';
import '../services/api_client.dart';
import 'core_providers.dart';

@immutable
class NotificationsListState {
  const NotificationsListState({
    required this.notifications,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<AppNotification> notifications;
  final bool hasMore;
  final bool isLoadingMore;

  NotificationsListState copyWith({
    List<AppNotification>? notifications,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return NotificationsListState(
      notifications: notifications ?? this.notifications,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// The Notifications inbox — paginated, newest first, same shape as
/// EventsListNotifier/the other paginated lists.
class NotificationsListNotifier
    extends StateNotifier<AsyncValue<NotificationsListState>> {
  NotificationsListNotifier(this._apiClient, this._ref)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _apiClient;
  final Ref _ref;
  int _page = 1;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _apiClient.notifications(page: 1);
      _page = 1;
      return NotificationsListState(
        notifications: response.data,
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
      final response = await _apiClient.notifications(page: _page + 1);
      _page += 1;
      state = AsyncValue.data(
        current.copyWith(
          notifications: [...current.notifications, ...response.data],
          hasMore: response.hasMorePages,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  /// Optimistic — flips the row to read locally immediately, then confirms
  /// with the server. Also refreshes the unread-count badge.
  Future<void> markRead(int notificationId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final alreadyRead = current.notifications
        .firstWhere((n) => n.id == notificationId)
        .readAt;
    if (alreadyRead != null) return;

    state = AsyncValue.data(
      current.copyWith(
        notifications: current.notifications
            .map(
              (n) => n.id == notificationId
                  ? n.copyWith(readAt: DateTime.now())
                  : n,
            )
            .toList(),
      ),
    );

    try {
      await _apiClient.markNotificationRead(notificationId);
    } finally {
      _ref.invalidate(unreadNotificationCountProvider);
    }
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(
        notifications: current.notifications
            .map((n) => n.copyWith(readAt: n.readAt ?? DateTime.now()))
            .toList(),
      ),
    );

    try {
      await _apiClient.markAllNotificationsRead();
    } finally {
      _ref.invalidate(unreadNotificationCountProvider);
    }
  }
}

final notificationsListProvider =
    StateNotifierProvider.autoDispose<
      NotificationsListNotifier,
      AsyncValue<NotificationsListState>
    >((ref) => NotificationsListNotifier(ref.watch(apiClientProvider), ref));

/// The bell icon's unread badge — refreshed on app start, after mark-read/
/// mark-all-read, and on a foreground FCM message (see
/// PushNotificationService).
final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  return apiClient.unreadNotificationCount();
});
