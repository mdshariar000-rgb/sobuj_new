import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/groups/group_settings_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Group _buildGroup({
  required int id,
  required String name,
  String? description,
  String visibility = 'public',
}) {
  return Group(
    id: id,
    name: name,
    slug: name.toLowerCase().replaceAll(' ', '-'),
    description: description,
    visibility: visibility,
    myRole: 'admin',
    isMember: true,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpSettings(
  WidgetTester tester,
  FakeApiClient fakeClient,
  Group group,
) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  fakeClient.meResult = buildFakeUser(id: 1, name: 'Me');

  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(430, 1600));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
      child: MaterialApp(home: GroupSettingsScreen(group: group)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('pre-fills the real current name, description, and privacy', (
    tester,
  ) async {
    final group = _buildGroup(
      id: 1,
      name: 'Rare Seed Traders',
      description: 'Heirloom seed swaps.',
      visibility: 'private',
    );

    await _pumpSettings(tester, FakeApiClient(), group);

    expect(find.text('Rare Seed Traders'), findsOneWidget);
    expect(find.text('Heirloom seed swaps.'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('group-settings-private-switch')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('saving sends the real edited fields to the API', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Rare Seed Traders');
    final fakeClient = FakeApiClient()
      ..updateGroupResult = _buildGroup(id: 1, name: 'Rare Seed Traders');

    await _pumpSettings(tester, fakeClient, group);

    await tester.enterText(
      find.byKey(const Key('group-settings-description-field')),
      'Now with more heirloom varieties.',
    );

    final privateSwitch = find.byKey(
      const Key('group-settings-private-switch'),
    );
    await tester.tap(privateSwitch);
    await tester.pump();

    await tester.tap(find.byKey(const Key('group-settings-save-button')));
    await tester.pumpAndSettle();

    expect(
      fakeClient.lastUpdateGroupPinnedMessage,
      isNull,
    ); // untouched by this screen
    expect(fakeClient.lastUpdateGroupIsPrivate, isTrue);
  });

  testWidgets(
    'lays out without overflow at a real phone width (not the wider default test surface)',
    (tester) async {
      final group = _buildGroup(
        id: 1,
        name: 'A Very Long Group Name About Urban Fruit & Citrus Growers',
        description: 'A' * 400,
      );

      await _pumpSettings(tester, FakeApiClient(), group);

      expect(tester.takeException(), isNull);
    },
  );
}
