import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/subscription_status.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/agri_ai/agri_ai_paywall_screen.dart';
import 'package:shobuj_mobile/screens/profile/manage_subscription_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Future<void> _pump(WidgetTester tester, FakeApiClient fakeClient) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
      child: const MaterialApp(home: ManageSubscriptionScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows an active plan with its renewal date', (tester) async {
    final fakeClient = FakeApiClient()
      ..subscriptionStatusResult = SubscriptionStatus(
        hasAccess: true,
        plan: 'annual',
        status: 'active',
        onTrial: false,
        cancelAtPeriodEnd: false,
        renewsAt: DateTime(2027, 3, 15),
      );

    await _pump(tester, fakeClient);

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Annual'), findsOneWidget);
    expect(find.text('Renews on'), findsOneWidget);
    expect(find.text('March 15, 2027'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Cancel Subscription'), findsOneWidget);
  });

  testWidgets('shows trial status and the trial end date', (tester) async {
    final fakeClient = FakeApiClient()
      ..subscriptionStatusResult = SubscriptionStatus(
        hasAccess: true,
        plan: 'monthly',
        status: 'trialing',
        onTrial: true,
        trialEndsAt: DateTime(2026, 9, 20),
        cancelAtPeriodEnd: false,
      );

    await _pump(tester, fakeClient);

    expect(find.text('Trial'), findsOneWidget);
    expect(find.text('Free trial ends'), findsOneWidget);
    expect(find.text('September 20, 2026'), findsOneWidget);
  });

  testWidgets(
    'a canceled-but-not-yet-ended subscription hides the cancel button and shows the end date',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..subscriptionStatusResult = SubscriptionStatus(
          hasAccess: true,
          plan: 'monthly',
          status: 'active',
          onTrial: false,
          cancelAtPeriodEnd: true,
          endsAt: DateTime(2026, 10, 1),
        );

      await _pump(tester, fakeClient);

      expect(find.text('Canceling'), findsOneWidget);
      expect(find.text('Access ends'), findsOneWidget);
      expect(find.text('October 1, 2026'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Cancel Subscription'), findsNothing);
    },
  );

  testWidgets(
    'a never-subscribed user sees a prompt into the paywall instead of a plan card',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..subscriptionStatusResult = const SubscriptionStatus(
          hasAccess: false,
          onTrial: false,
          cancelAtPeriodEnd: false,
        );

      await _pump(tester, fakeClient);

      expect(find.text("You're not subscribed to Agri-AI Premium"), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'View Plans'));
      await tester.pumpAndSettle();

      expect(find.byType(AgriAiPaywallScreen), findsOneWidget);
    },
  );

  testWidgets(
    'confirming Cancel Subscription calls the API and shows a confirmation',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..subscriptionStatusResult = SubscriptionStatus(
          hasAccess: true,
          plan: 'monthly',
          status: 'active',
          onTrial: false,
          cancelAtPeriodEnd: false,
          renewsAt: DateTime(2026, 10, 1),
        )
        ..cancelSubscriptionResult = SubscriptionStatus(
          hasAccess: true,
          plan: 'monthly',
          status: 'active',
          onTrial: false,
          cancelAtPeriodEnd: true,
          endsAt: DateTime(2026, 10, 1),
        );

      await _pump(tester, fakeClient);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel Subscription'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Agri-AI Premium?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel Subscription'));
      await tester.pumpAndSettle();

      expect(fakeClient.cancelSubscriptionCalled, isTrue);
      expect(find.text('Your subscription has been canceled.'), findsOneWidget);
    },
  );

  testWidgets('dismissing the cancel dialog with Keep Subscription does not cancel', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..subscriptionStatusResult = SubscriptionStatus(
        hasAccess: true,
        plan: 'monthly',
        status: 'active',
        onTrial: false,
        cancelAtPeriodEnd: false,
      );

    await _pump(tester, fakeClient);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel Subscription'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Keep Subscription'));
    await tester.pumpAndSettle();

    expect(fakeClient.cancelSubscriptionCalled, isFalse);
  });
}
