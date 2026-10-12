import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/models/group_category.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/groups/create_group_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Future<void> _pumpCreateGroupScreen(
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
      child: const MaterialApp(home: CreateGroupScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the category field is a picker over the real admin-managed list, '
    'not free text',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..groupCategoriesResult = const [
          GroupCategory(id: 1, name: 'Vegetable Growing'),
          GroupCategory(id: 2, name: 'Hydroponics & Tech'),
        ];

      await _pumpCreateGroupScreen(tester, fakeClient);

      // No free-text entry point for a category anymore.
      expect(
        find.byKey(const Key('create-group-category-field')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('create-group-category-field')));
      await tester.pumpAndSettle();

      expect(find.text('Vegetable Growing'), findsOneWidget);
      expect(find.text('Hydroponics & Tech'), findsOneWidget);
      // "No category" appears both as the current (unselected) value in the
      // closed field and as an option in the now-open menu.
      expect(find.text('No category'), findsWidgets);
    },
  );

  testWidgets(
    'selecting a category and creating the group sends that real category',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..groupCategoriesResult = const [
          GroupCategory(id: 1, name: 'Vegetable Growing'),
          GroupCategory(id: 2, name: 'Hydroponics & Tech'),
        ]
        ..createGroupResult = Group(
          id: 1,
          name: 'Tomato Growers',
          slug: 'tomato-growers',
          category: 'Vegetable Growing',
          isMember: true,
          createdAt: DateTime(2026, 1, 1),
        );

      await _pumpCreateGroupScreen(tester, fakeClient);

      await tester.enterText(
        find.byKey(const Key('create-group-name-field')),
        'Tomato Growers',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('create-group-slug-field')),
        'tomato-growers',
      );

      await tester.tap(find.byKey(const Key('create-group-category-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vegetable Growing').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastCreateGroupCategory, 'Vegetable Growing');
    },
  );

  testWidgets('creating a group without picking a category sends no category', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..createGroupResult = Group(
        id: 1,
        name: 'Tomato Growers',
        slug: 'tomato-growers',
        isMember: true,
        createdAt: DateTime(2026, 1, 1),
      );

    await _pumpCreateGroupScreen(tester, fakeClient);

    await tester.enterText(
      find.byKey(const Key('create-group-name-field')),
      'Tomato Growers',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('create-group-slug-field')),
      'tomato-growers',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(fakeClient.lastCreateGroupCategory, isNull);
  });

  testWidgets(
    'defaults to a public group, and toggling Private sends that real '
    'visibility',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..createGroupResult = Group(
          id: 1,
          name: 'Tomato Growers',
          slug: 'tomato-growers',
          isMember: true,
          createdAt: DateTime(2026, 1, 1),
        );

      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(430, 1600));

      await _pumpCreateGroupScreen(tester, fakeClient);

      final privateSwitch = find.byKey(
        const Key('create-group-private-switch'),
      );
      expect(privateSwitch, findsOneWidget);
      expect(tester.widget<SwitchListTile>(privateSwitch).value, isFalse);

      await tester.enterText(
        find.byKey(const Key('create-group-name-field')),
        'Tomato Growers',
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('create-group-slug-field')),
        'tomato-growers',
      );

      await tester.tap(privateSwitch);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(privateSwitch).value, isTrue);

      await tester.tap(find.widgetWithText(FilledButton, 'Create'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastCreateGroupIsPrivate, isTrue);
    },
  );
}
