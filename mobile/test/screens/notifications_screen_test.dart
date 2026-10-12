import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/app_notification.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/post.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/notifications/notifications_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

AppNotification _buildNotification({
  int id = 1,
  String title = 'Rina liked your post',
  String body = 'Tomato progress update',
  DateTime? readAt,
}) {
  return AppNotification(
    id: id,
    type: 'post_liked',
    title: title,
    body: body,
    data: const {'post_id': 5},
    actor: buildFakeUser(id: 2, name: 'Rina'),
    readAt: readAt,
    createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
  );
}

Future<void> _pumpNotifications(
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
      child: const MaterialApp(home: NotificationsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows an empty state when there are no notifications', (
    tester,
  ) async {
    await _pumpNotifications(tester, FakeApiClient());

    expect(find.text("You're all caught up"), findsOneWidget);
  });

  testWidgets('shows real notifications, newest first', (tester) async {
    final fakeClient = FakeApiClient()
      ..notificationsResult = PaginatedResponse(
        data: [
          _buildNotification(id: 1, title: 'Rina liked your post'),
          _buildNotification(id: 2, title: 'Carlos commented on your post'),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pumpNotifications(tester, fakeClient);

    expect(find.text('Rina liked your post'), findsOneWidget);
    expect(find.text('Carlos commented on your post'), findsOneWidget);
  });

  testWidgets(
    'tapping an unread notification marks it read and opens the real post',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..notificationsResult = PaginatedResponse(
          data: [_buildNotification(id: 7)],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        )
        ..markNotificationReadResult = _buildNotification(
          id: 7,
          readAt: DateTime.now(),
        )
        ..postResult = Post(
          id: 5,
          body: 'Real post body',
          author: buildFakeUser(id: 2, name: 'Rina'),
          createdAt: DateTime.now(),
        );

      await _pumpNotifications(tester, fakeClient);

      await tester.tap(find.text('Rina liked your post'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastMarkedReadNotificationId, 7);
      expect(find.text('Real post body'), findsOneWidget);
    },
  );

  testWidgets(
    'Mark all read calls the API and clears the bold/unread styling',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..notificationsResult = PaginatedResponse(
          data: [_buildNotification(id: 1)],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await _pumpNotifications(tester, fakeClient);

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(fakeClient.markAllNotificationsReadCalled, isTrue);
    },
  );
}
