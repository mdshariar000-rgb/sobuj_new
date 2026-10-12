import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/models/group_member.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/post.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/groups/group_chat_screen.dart';
import 'package:shobuj_mobile/screens/groups/group_detail_screen.dart';

import 'package:shobuj_mobile/theme/app_theme.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Group _buildGroup({
  required int id,
  required String name,
  bool? isMember,
  int membersCount = 3,
  int? postsCount,
  String? category,
  String visibility = 'public',
  bool? joinRequestPending,
  int? pendingJoinRequestsCount,
  String? myRole,
}) {
  return Group(
    id: id,
    name: name,
    slug: name.toLowerCase().replaceAll(' ', '-'),
    description: 'A friendly place to talk plants.',
    category: category,
    visibility: visibility,
    membersCount: membersCount,
    postsCount: postsCount,
    isMember: isMember,
    joinRequestPending: joinRequestPending,
    pendingJoinRequestsCount: pendingJoinRequestsCount,
    myRole: myRole,
    createdAt: DateTime(2026, 1, 1),
  );
}

Post _buildPost({
  required int id,
  required String body,
  String? imageUrl,
  String approvalStatus = 'approved',
}) {
  return Post(
    id: id,
    groupId: 1,
    body: body,
    imageUrl: imageUrl,
    approvalStatus: approvalStatus,
    commentsCount: 0,
    author: buildFakeUser(id: 2, name: 'Rina'),
    createdAt: DateTime.now(),
  );
}

Future<void> _pumpGroupDetail(
  WidgetTester tester,
  FakeApiClient fakeClient,
  Group group,
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
      child: MaterialApp(home: GroupDetailScreen(group: group)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'the group name in the dark app bar is white under the real app theme',
    (tester) async {
      // The app theme's AppBar title style has its own dark color, which
      // used to beat this bar's white foregroundColor — dark on dark green.
      GoogleFonts.config.allowRuntimeFetching = false;
      final group = _buildGroup(id: 1, name: 'Tomato Growers', isMember: true);
      final fakeClient = FakeApiClient();
      final fakeStorage = FakeSecureStorageService();
      await fakeStorage.saveToken('existing-token');
      fakeClient.meResult = buildFakeUser(id: 1, name: 'Me');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            secureStorageProvider.overrideWithValue(fakeStorage),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: GroupDetailScreen(group: group),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Tomato Growers'),
      );
      expect(title, findsOneWidget);
      expect(
        DefaultTextStyle.of(tester.element(title)).style.color,
        Colors.white,
      );
    },
  );

  testWidgets('shows the group header and its discussion posts', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers', isMember: true);
    final fakeClient = FakeApiClient()
      ..groupPostsResult = PaginatedResponse(
        data: [_buildPost(id: 1, body: 'Welcome to the group!')],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpGroupDetail(tester, fakeClient, group);

    expect(find.text('A friendly place to talk plants.'), findsOneWidget);
    expect(find.text('3 members'), findsOneWidget);
    expect(find.text('Welcome to the group!'), findsOneWidget);
    expect(find.textContaining('Public Group'), findsOneWidget);
  });

  testWidgets('shows an empty state when the discussion has no posts', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers', isMember: true);
    await _pumpGroupDetail(tester, FakeApiClient(), group);

    expect(find.text('No posts yet — start the conversation.'), findsOneWidget);
  });

  testWidgets('joining the group calls the API and flips the button', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers', isMember: false);
    final fakeClient = FakeApiClient()
      ..joinGroupResult = _buildGroup(
        id: 1,
        name: 'Tomato Growers',
        isMember: true,
        membersCount: 4,
      );

    await _pumpGroupDetail(tester, fakeClient, group);

    expect(find.widgetWithText(FilledButton, 'Join Group'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Join Group'));
    await tester.pumpAndSettle();

    expect(fakeClient.joinedGroupId, 1);
    expect(find.widgetWithText(FilledButton, 'Joined'), findsOneWidget);
  });

  testWidgets('Group Chat is disabled until the user has joined', (
    tester,
  ) async {
    final notMember = _buildGroup(
      id: 1,
      name: 'Tomato Growers',
      isMember: false,
    );
    await _pumpGroupDetail(tester, FakeApiClient(), notMember);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Chat'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('a member can open Group Chat', (tester) async {
    final member = _buildGroup(id: 1, name: 'Tomato Growers', isMember: true);
    await _pumpGroupDetail(tester, FakeApiClient(), member);

    await tester.tap(find.widgetWithText(FilledButton, 'Chat'));
    await tester.pumpAndSettle();

    expect(find.byType(GroupChatScreen), findsOneWidget);
  });

  testWidgets('posting into the discussion adds it to the top', (tester) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers', isMember: true);
    final fakeClient = FakeApiClient()
      ..groupPostsResult = PaginatedResponse(
        data: [_buildPost(id: 1, body: 'Existing post')],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      )
      ..createPostResult = _buildPost(id: 2, body: 'A brand new topic');

    await _pumpGroupDetail(tester, fakeClient, group);

    await tester.tap(find.byKey(const Key('group-detail-composer')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'A brand new topic');
    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pumpAndSettle();

    expect(find.text('A brand new topic'), findsOneWidget);
    expect(find.text('Existing post'), findsOneWidget);
  });

  testWidgets('Media & Photos tab shows only posts with a real photo', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers', isMember: true);
    final fakeClient = FakeApiClient()
      ..groupPostsResult = PaginatedResponse(
        data: [
          _buildPost(id: 1, body: 'No photo here'),
          _buildPost(
            id: 2,
            body: 'A bloom shot',
            imageUrl: 'https://example.com/bloom.jpg',
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pumpGroupDetail(tester, fakeClient, group);

    await tester.tap(find.text('Media & Photos'));
    await tester.pumpAndSettle();

    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('Members tab shows the real roster with real roles', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers', isMember: true);
    final fakeClient = FakeApiClient()
      ..groupMembersResult = PaginatedResponse(
        data: [
          GroupMember(
            id: 1,
            name: 'Admin Elena',
            isVerified: false,
            isAdmin: true,
            joinedAt: DateTime(2026, 1, 1),
          ),
          GroupMember(
            id: 2,
            name: 'Carlos Mendoza',
            isVerified: false,
            isAdmin: false,
            joinedAt: DateTime(2026, 1, 2),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pumpGroupDetail(tester, fakeClient, group);

    await tester.tap(find.textContaining('Members'));
    await tester.pumpAndSettle();

    expect(find.text('Admin Elena'), findsOneWidget);
    expect(find.text('Carlos Mendoza'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets('shows a real category badge and total post count', (
    tester,
  ) async {
    final group = _buildGroup(
      id: 1,
      name: 'Tomato Growers',
      isMember: true,
      postsCount: 1200,
      category: 'Popular Circle',
    );
    final fakeClient = FakeApiClient()
      ..groupPostsResult = PaginatedResponse(
        data: [_buildPost(id: 1, body: 'Welcome to the group!')],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpGroupDetail(tester, fakeClient, group);

    expect(find.text('Popular Circle'), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);
  });

  testWidgets(
    'the search icon reveals a field that filters posts already loaded',
    (tester) async {
      final group = _buildGroup(id: 1, name: 'Tomato Growers', isMember: true);
      final fakeClient = FakeApiClient()
        ..groupPostsResult = PaginatedResponse(
          data: [
            _buildPost(id: 1, body: 'Anyone tried neem spray on aphids?'),
            _buildPost(id: 2, body: 'My tomatoes are finally blooming'),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 2,
        );

      await _pumpGroupDetail(tester, fakeClient, group);

      expect(find.text('Anyone tried neem spray on aphids?'), findsOneWidget);
      expect(find.text('My tomatoes are finally blooming'), findsOneWidget);

      await tester.tap(find.byKey(const Key('group-detail-search-button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('group-detail-search-field')),
        'neem',
      );
      await tester.pumpAndSettle();

      expect(find.text('Anyone tried neem spray on aphids?'), findsOneWidget);
      expect(find.text('My tomatoes are finally blooming'), findsNothing);
    },
  );

  testWidgets('the app bar chat icon opens Group Chat for a member', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers', isMember: true);
    await _pumpGroupDetail(tester, FakeApiClient(), group);

    await tester.tap(find.byIcon(Icons.chat_bubble_outline).first);
    await tester.pumpAndSettle();

    expect(find.byType(GroupChatScreen), findsOneWidget);
  });

  testWidgets(
    'lays out without overflow at a real phone width (not the wider default test surface)',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final group = _buildGroup(
        id: 1,
        name: 'A Very Long Group Name About Urban Fruit & Citrus Growers',
        isMember: true,
        membersCount: 4800,
      );
      final fakeClient = FakeApiClient()
        ..groupPostsResult = PaginatedResponse(
          data: [_buildPost(id: 1, body: 'Welcome to the group!')],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await _pumpGroupDetail(tester, fakeClient, group);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a private group shows Private Group and Request to Join, and '
      'requesting flips it to a disabled Request Pending', (tester) async {
    final group = _buildGroup(
      id: 1,
      name: 'Rare Seed Traders',
      isMember: false,
      visibility: 'private',
    );
    final fakeClient = FakeApiClient()..joinGroupReturnsRequest = true;

    await _pumpGroupDetail(tester, fakeClient, group);

    expect(find.textContaining('Private Group'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Request to Join'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Request to Join'));
    await tester.pumpAndSettle();

    expect(fakeClient.joinedGroupId, 1);
    expect(
      find.widgetWithText(FilledButton, 'Request Pending'),
      findsOneWidget,
    );
  });

  testWidgets(
    'tapping Request Pending cancels the request and reverts the button',
    (tester) async {
      final group = _buildGroup(
        id: 1,
        name: 'Rare Seed Traders',
        isMember: false,
        visibility: 'private',
        joinRequestPending: true,
      );
      final fakeClient = FakeApiClient();

      await _pumpGroupDetail(tester, fakeClient, group);

      await tester.tap(find.widgetWithText(FilledButton, 'Request Pending'));
      await tester.pumpAndSettle();

      expect(fakeClient.canceledJoinRequestGroupId, 1);
      expect(
        find.widgetWithText(FilledButton, 'Request to Join'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'an admin with pending join requests sees the banner and can open the '
    'requests screen',
    (tester) async {
      final group = _buildGroup(
        id: 1,
        name: 'Rare Seed Traders',
        isMember: true,
        visibility: 'private',
        myRole: 'admin',
        pendingJoinRequestsCount: 2,
      );

      await _pumpGroupDetail(tester, FakeApiClient(), group);

      final banner = find.byKey(
        const Key('group-detail-pending-requests-banner'),
      );
      expect(banner, findsOneWidget);
      expect(find.text('2 pending join requests'), findsOneWidget);

      await tester.tap(banner);
      await tester.pumpAndSettle();

      expect(find.text('Join Requests'), findsOneWidget);
    },
  );

  testWidgets(
    'a non-admin member sees no pending-requests banner or settings icon',
    (tester) async {
      final group = _buildGroup(
        id: 1,
        name: 'Rare Seed Traders',
        isMember: true,
        visibility: 'private',
        myRole: 'member',
        pendingJoinRequestsCount: 2,
      );

      await _pumpGroupDetail(tester, FakeApiClient(), group);

      expect(
        find.byKey(const Key('group-detail-pending-requests-banner')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('group-detail-settings-button')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a pending post shows the real badge, and its group admin can approve '
    'or reject it inline',
    (tester) async {
      final group = _buildGroup(
        id: 1,
        name: 'Rare Seed Traders',
        isMember: true,
        visibility: 'private',
        myRole: 'admin',
      );
      final fakeClient = FakeApiClient()
        ..groupPostsResult = PaginatedResponse(
          data: [
            _buildPost(
              id: 1,
              body: 'Awaiting review',
              approvalStatus: 'pending',
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await _pumpGroupDetail(tester, fakeClient, group);

      expect(find.text('Pending Approval'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Approve'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Reject'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Approve'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastApprovedPostId, 1);
      expect(find.text('Pending Approval'), findsNothing);
    },
  );
}
