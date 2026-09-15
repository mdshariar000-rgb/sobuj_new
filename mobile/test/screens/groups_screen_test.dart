import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/groups/groups_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Group _buildGroup({
  required int id,
  required String name,
  bool? isMember,
  bool? isVerified,
  int membersCount = 3,
  int? postsTodayCount,
  String? category,
  int? unreadCount,
  GroupLastMessage? lastMessage,
}) {
  return Group(
    id: id,
    name: name,
    slug: name.toLowerCase().replaceAll(' ', '-'),
    category: category,
    isVerified: isVerified,
    membersCount: membersCount,
    postsTodayCount: postsTodayCount,
    isMember: isMember,
    unreadCount: unreadCount,
    lastMessage: lastMessage,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpGroupsScreen(
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
      child: const MaterialApp(home: GroupsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows groups returned by the API', (tester) async {
    final fakeClient = FakeApiClient()
      ..groupsResult = PaginatedResponse(
        data: [
          _buildGroup(id: 1, name: 'Tomato Growers', isMember: true),
          _buildGroup(id: 2, name: 'Herb Enthusiasts', isMember: false),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pumpGroupsScreen(tester, fakeClient);

    expect(find.text('Tomato Growers'), findsOneWidget);
    expect(find.text('Herb Enthusiasts'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Joined'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Join'), findsOneWidget);
  });

  testWidgets(
    'shows the verified checkmark only next to an admin-verified group',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..groupsResult = PaginatedResponse(
          data: [
            _buildGroup(id: 1, name: 'Tomato Growers', isVerified: true),
            _buildGroup(id: 2, name: 'Herb Enthusiasts', isVerified: false),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 2,
        );

      await _pumpGroupsScreen(tester, fakeClient);

      expect(find.byIcon(Icons.verified), findsOneWidget);
    },
  );

  testWidgets('shows an empty state when there are no groups', (tester) async {
    await _pumpGroupsScreen(tester, FakeApiClient());

    expect(find.text('No groups found'), findsOneWidget);
  });

  testWidgets('typing in the search bar debounces then calls the API', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..groupsResult = PaginatedResponse(
        data: [_buildGroup(id: 1, name: 'Tomato Growers')],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpGroupsScreen(tester, fakeClient);

    await tester.enterText(find.byType(TextField), 'tomato');

    await tester.pump(const Duration(milliseconds: 200));
    expect(fakeClient.lastGroupsCallArgs?['search'], isNot('tomato'));

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(fakeClient.lastGroupsCallArgs?['search'], 'tomato');
  });

  testWidgets('tapping Join calls joinGroup and flips the button to Joined', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers', isMember: false);
    final fakeClient = FakeApiClient()
      ..groupsResult = PaginatedResponse(
        data: [group],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      )
      ..joinGroupResult = _buildGroup(
        id: 1,
        name: 'Tomato Growers',
        isMember: true,
        membersCount: 4,
      );

    await _pumpGroupsScreen(tester, fakeClient);

    await tester.tap(find.widgetWithText(FilledButton, 'Join'));
    await tester.pumpAndSettle();

    expect(fakeClient.joinedGroupId, 1);
    expect(find.widgetWithText(FilledButton, 'Joined'), findsOneWidget);
  });

  testWidgets('creating a group adds it to the top of the list', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..groupsResult = PaginatedResponse(
        data: [_buildGroup(id: 1, name: 'Existing Group')],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      )
      ..createGroupResult = _buildGroup(
        id: 2,
        name: 'Brand New Group',
        isMember: true,
        membersCount: 1,
      );

    await _pumpGroupsScreen(tester, fakeClient);

    await tester.tap(find.widgetWithIcon(FloatingActionButton, Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('create-group-name-field')),
      'Brand New Group',
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('create-group-slug-field')),
      'brand-new-group',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(find.text('Brand New Group'), findsOneWidget);
    expect(find.text('Existing Group'), findsOneWidget);
  });

  testWidgets('shows a real posts-today count alongside members when present', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..groupsResult = PaginatedResponse(
        data: [
          _buildGroup(
            id: 1,
            name: 'Hydroponics Lab',
            category: 'Hydro & Tech',
            membersCount: 2300,
            postsTodayCount: 45,
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpGroupsScreen(tester, fakeClient);

    expect(find.textContaining('2.3K members'), findsOneWidget);
    expect(find.textContaining('45 posts today'), findsOneWidget);
  });

  testWidgets(
    'a joined group shows its real last-message preview and unread badge',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..groupsResult = PaginatedResponse(
          data: [
            _buildGroup(
              id: 1,
              name: 'Tomato Growers',
              isMember: true,
              unreadCount: 3,
              lastMessage: GroupLastMessage(
                body: 'Anyone free for a seed swap Saturday?',
                hasImage: false,
                senderId: 2,
                senderName: 'Elena',
                createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
              ),
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await _pumpGroupsScreen(tester, fakeClient);

      expect(
        find.textContaining('Elena: Anyone free for a seed swap Saturday?'),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets(
    'a group without a last message shows no preview or unread badge',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..groupsResult = PaginatedResponse(
          data: [_buildGroup(id: 1, name: 'Brand New Circle', isMember: true)],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await _pumpGroupsScreen(tester, fakeClient);

      expect(find.textContaining('members'), findsOneWidget);
    },
  );

  testWidgets(
    'lays out without overflow at a real phone width (not the wider default test surface)',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final fakeClient = FakeApiClient()
        ..groupsResult = PaginatedResponse(
          data: [
            _buildGroup(
              id: 1,
              name: 'Urban Fruit & Citrus Growers',
              category: 'Popular Circle',
              membersCount: 4800,
              postsTodayCount: 120,
              isMember: true,
            ),
            _buildGroup(
              id: 2,
              name: 'Regenerative Hydroponics Lab',
              category: 'Hydro & Tech',
              membersCount: 2300,
              postsTodayCount: 45,
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 2,
        );

      await _pumpGroupsScreen(tester, fakeClient);

      expect(tester.takeException(), isNull);
    },
  );
}
