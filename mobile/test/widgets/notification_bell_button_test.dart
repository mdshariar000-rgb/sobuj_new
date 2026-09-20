import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/providers/notification_providers.dart';
import 'package:shobuj_mobile/widgets/notification_bell_button.dart';

Future<void> _pumpBell(WidgetTester tester, int unreadCount) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        unreadNotificationCountProvider.overrideWith((ref) async => unreadCount),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: NotificationBellButton(onTap: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows no badge when there are no unread notifications', (
    tester,
  ) async {
    await _pumpBell(tester, 0);

    expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('shows the real unread count as a badge', (tester) async {
    await _pumpBell(tester, 3);

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('shows 9+ once the unread count exceeds 9', (tester) async {
    await _pumpBell(tester, 15);

    expect(find.text('9+'), findsOneWidget);
  });

  testWidgets('tapping the bell calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          unreadNotificationCountProvider.overrideWith((ref) async => 0),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: NotificationBellButton(onTap: () => tapped = true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_outlined));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });
}
