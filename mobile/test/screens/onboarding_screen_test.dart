import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/onboarding_providers.dart';
import 'package:shobuj_mobile/screens/onboarding/onboarding_screen.dart';
import 'package:shobuj_mobile/theme/app_theme.dart';

import '../support/fake_api_client.dart';

Group _group(
  int id,
  String name, {
  bool isMember = false,
  bool isLocal = false,
  int? localMembersCount,
}) => Group(
  id: id,
  name: name,
  slug: name.toLowerCase().replaceAll(' ', '-'),
  membersCount: 12,
  isMember: isMember,
  isLocal: isLocal,
  localMembersCount: localMembersCount,
  createdAt: DateTime(2026, 1, 1),
);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeApiClient fakeClient,
) async {
  final container = ProviderContainer(
    overrides: [apiClientProvider.overrideWithValue(fakeClient)],
  );
  addTearDown(container.dispose);
  container.read(needsOnboardingProvider.notifier).state = true;

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      // The real theme — its full-width buttons once broke this screen's
      // bottom row.
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const OnboardingScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('join groups, then finish', (tester) async {
    final fakeClient = FakeApiClient()
      ..suggestedGroupsResult = [_group(3, 'Tomato Growers')]
      ..joinGroupResult = _group(3, 'Tomato Growers');

    final container = await _pump(tester, fakeClient);

    expect(find.text('Join a few groups'), findsOneWidget);
    expect(find.text('Follow growers near you'), findsNothing);

    await tester.tap(find.byKey(const Key('join-3')));
    await tester.pumpAndSettle();
    expect(fakeClient.joinedGroupId, 3);
    expect(find.text('Joined'), findsOneWidget);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(container.read(needsOnboardingProvider), isFalse);
  });

  testWidgets('groups for the user\'s city are listed first', (tester) async {
    final fakeClient = FakeApiClient()
      ..suggestedGroupsCity = 'Leeds'
      ..suggestedGroupsResult = [
        _group(1, 'Leeds Allotments', isLocal: true),
        _group(2, 'Herb Lovers', isLocal: true, localMembersCount: 4),
        _group(3, 'UK Veg Growers'),
      ];

    await _pump(tester, fakeClient);

    expect(find.text('Groups in Leeds'), findsOneWidget);
    expect(find.text('Popular groups'), findsOneWidget);
    expect(find.textContaining('4 in Leeds'), findsOneWidget);
    // Nothing is joined automatically any more.
    expect(find.text('Joined'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Leeds Allotments')).dy,
      lessThan(tester.getTopLeft(find.text('Popular groups')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Popular groups')).dy,
      lessThan(tester.getTopLeft(find.text('UK Veg Growers')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('says so when the city has no groups yet', (tester) async {
    final fakeClient = FakeApiClient()
      ..suggestedGroupsCity = 'Truro'
      ..suggestedGroupsResult = [_group(3, 'UK Veg Growers')];

    await _pump(tester, fakeClient);

    expect(find.text('Groups in Truro'), findsOneWidget);
    expect(find.byKey(const Key('onboarding-no-city-groups')), findsOneWidget);
    expect(find.text('UK Veg Growers'), findsOneWidget);
  });

  testWidgets(
    'with no groups to suggest it says so, and Skip ends onboarding',
    (tester) async {
      final container = await _pump(tester, FakeApiClient());

      expect(
        find.textContaining('No public groups to suggest'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(container.read(needsOnboardingProvider), isFalse);
    },
  );
}
