import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/services/api_exception.dart';
import 'package:shobuj_mobile/providers/group_providers.dart';
import 'package:shobuj_mobile/screens/groups/group_chat_screen.dart';
import 'package:shobuj_mobile/screens/groups/groups_screen.dart';
import 'package:shobuj_mobile/services/group_realtime_channel.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

class _FakeGroupRealtimeChannel extends GroupRealtimeChannel {
  _FakeGroupRealtimeChannel() : super(dio: Dio(), groupId: 0);

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {}
}

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
        // Opening a group chat from the list mustn't try a real socket.
        groupRealtimeChannelProvider.overrideWith(
          (ref, groupId) => _FakeGroupRealtimeChannel(),
        ),
      ],
      child: const MaterialApp(home: GroupsScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDiscover(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('groups-tab-discover')));
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

    // My groups (the default tab): only the one you're in, with its menu.
    expect(find.text('My groups (1)'), findsOneWidget);
    expect(find.text('Tomato Growers'), findsOneWidget);
    expect(find.text('Herb Enthusiasts'), findsNothing);
    expect(find.byKey(const Key('group-menu-1')), findsOneWidget);

    // Discover: the rest, each with Join.
    await _openDiscover(tester);
    expect(find.text('Herb Enthusiasts'), findsOneWidget);
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
      await _openDiscover(tester);

      expect(find.byIcon(Icons.verified), findsOneWidget);
    },
  );

  testWidgets('only a joined group has a chat button, carrying its unread '
      'count', (tester) async {
    final fakeClient = FakeApiClient()
      ..groupsResult = PaginatedResponse(
        data: [
          _buildGroup(
            id: 1,
            name: 'Tomato Growers',
            isMember: true,
            unreadCount: 3,
          ),
          _buildGroup(id: 2, name: 'Herb Enthusiasts', isMember: false),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pumpGroupsScreen(tester, fakeClient);

    final chatButton = find.byKey(const Key('group-chat-button-1'));
    await tester.ensureVisible(chatButton);
    await tester.pumpAndSettle();
    expect(chatButton, findsOneWidget);
    expect(find.byKey(const Key('group-chat-button-2')), findsNothing);
    expect(
      find.descendant(of: chatButton, matching: find.text('3')),
      findsOneWidget,
    );
  });

  testWidgets('the chat button opens the group chat and clears the unread '
      'count', (tester) async {
    final fakeClient = FakeApiClient()
      ..groupsResult = PaginatedResponse(
        data: [
          _buildGroup(
            id: 1,
            name: 'Tomato Growers',
            isMember: true,
            unreadCount: 3,
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpGroupsScreen(tester, fakeClient);

    final chatButton = find.byKey(const Key('group-chat-button-1'));
    await tester.ensureVisible(chatButton);
    await tester.pumpAndSettle();
    await tester.tap(chatButton);
    await tester.pumpAndSettle();

    expect(find.byType(GroupChatScreen), findsOneWidget);

    Navigator.of(tester.element(find.byType(GroupChatScreen))).pop();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: chatButton, matching: find.text('3')),
      findsNothing,
    );
  });

  testWidgets('shows an empty state when there are no groups', (tester) async {
    await _pumpGroupsScreen(tester, FakeApiClient());

    // My groups points you to Discover...
    expect(find.text('No groups yet'), findsOneWidget);
    await tester.tap(find.byKey(const Key('groups-empty-discover')));
    await tester.pumpAndSettle();
    // ...which has nothing either.
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
    await _openDiscover(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Join'));
    await tester.pumpAndSettle();

    expect(fakeClient.joinedGroupId, 1);
    // Joined: it moves off the Discover tab (and into My groups).
    expect(find.text('Tomato Growers'), findsNothing);
  });

  testWidgets('users cannot create groups from the Groups tab', (tester) async {
    final fakeClient = FakeApiClient()
      ..groupsResult = PaginatedResponse(
        data: [_buildGroup(id: 1, name: 'Existing Group')],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpGroupsScreen(tester, fakeClient);

    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Create a Group'), findsNothing);
  });

  testWidgets('shows members and when the group was last active', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..groupsResult = PaginatedResponse(
        data: [
          Group(
            id: 1,
            name: 'Hydroponics Lab',
            slug: 'hydroponics-lab',
            membersCount: 2300,
            lastActivityAt: DateTime.now().subtract(const Duration(hours: 2)),
            createdAt: DateTime(2026, 1, 1),
          ),
          Group(
            id: 2,
            name: 'Solo Group',
            slug: 'solo-group',
            membersCount: 1,
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pumpGroupsScreen(tester, fakeClient);
    await _openDiscover(tester);

    expect(find.textContaining('2.3K members • Active 2h ago'), findsOneWidget);
    expect(find.text('1 member'), findsOneWidget);
  });

  testWidgets('leaving asks first, and a failure is explained', (tester) async {
    final fakeClient = FakeApiClient()
      ..groupsResult = PaginatedResponse(
        data: [_buildGroup(id: 1, name: 'Tomato Growers', isMember: true)],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      )
      ..leaveGroupError = const ApiException(
        message: 'The group creator cannot leave their own group.',
      );

    await _pumpGroupsScreen(tester, fakeClient);

    await tester.tap(find.byKey(const Key('group-menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('group-leave-1')));
    await tester.pumpAndSettle();
    expect(find.text('Leave Tomato Growers?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-leave-group')));
    await tester.pumpAndSettle();

    expect(
      find.text('The group creator cannot leave their own group.'),
      findsOneWidget,
    );
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
