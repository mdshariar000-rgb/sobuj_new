import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/models/group_message.dart';
import 'package:shobuj_mobile/models/message_reaction.dart';
import 'package:shobuj_mobile/models/message_reply.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/group_providers.dart';
import 'package:shobuj_mobile/screens/groups/group_chat_screen.dart';
import 'package:shobuj_mobile/services/api_exception.dart';
import 'package:shobuj_mobile/services/group_realtime_channel.dart';
import 'package:shobuj_mobile/widgets/image_gallery_viewer.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

/// Lets a test hold the send request open, so it can assert on what's shown
/// while the request is still in flight — proving the message appears
/// instantly rather than only once the round trip completes.
class _DelayedSendApiClient extends FakeApiClient {
  final _completer = Completer<GroupMessage>();

  @override
  Future<GroupMessage> sendGroupMessage(
    int groupId, {
    String? body,
    List<File> images = const [],
    int? replyToId,
  }) {
    lastSentGroupMessageBody = body;
    return _completer.future;
  }

  void resolve(GroupMessage message) => _completer.complete(message);
}

class FakeGroupRealtimeChannel extends GroupRealtimeChannel {
  FakeGroupRealtimeChannel() : super(dio: Dio(), groupId: 0);

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {}
}

Group _buildGroup({
  required int id,
  required String name,
  bool isMember = true,
  int membersCount = 2,
  String? myRole,
  String? pinnedMessage,
}) {
  return Group(
    id: id,
    name: name,
    slug: name.toLowerCase().replaceAll(' ', '-'),
    membersCount: membersCount,
    isMember: isMember,
    myRole: myRole,
    pinnedMessage: pinnedMessage,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpGroupChat(
  WidgetTester tester,
  FakeApiClient fakeClient,
  Group group, {
  void Function(FakeGroupRealtimeChannel channel)? onChannelCreated,
}) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  fakeClient.meResult = buildFakeUser(id: 1, name: 'Me');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
        groupRealtimeChannelProvider.overrideWith((ref, groupId) {
          final channel = FakeGroupRealtimeChannel();
          onChannelCreated?.call(channel);
          return channel;
        }),
      ],
      child: MaterialApp(home: GroupChatScreen(group: group)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows real chat history with sender names and admin badge', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers');
    final fakeClient = FakeApiClient()
      ..groupMessagesResult = PaginatedResponse(
        data: [
          GroupMessage(
            id: 1,
            groupId: 1,
            body: 'Welcome new growers!',
            sender: buildFakeUser(id: 2, name: 'Elena'),
            senderIsAdmin: true,
            createdAt: DateTime.now(),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpGroupChat(tester, fakeClient, group);

    expect(find.text('Welcome new growers!'), findsOneWidget);
    expect(find.text('Elena'), findsOneWidget);
    expect(find.text('Admin'), findsOneWidget);
  });

  testWidgets(
    'a multi-photo message shows a grid, and tapping a photo opens them all',
    (tester) async {
      final group = _buildGroup(id: 1, name: 'Tomato Growers');
      final fakeClient = FakeApiClient()
        ..groupMessagesResult = PaginatedResponse(
          data: [
            GroupMessage(
              id: 1,
              groupId: 1,
              body: 'My harvest',
              imageUrls: [
                for (var i = 1; i <= 5; i++) 'https://example.com/p$i.jpg',
              ],
              sender: buildFakeUser(id: 2, name: 'Elena'),
              createdAt: DateTime.now(),
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await _pumpGroupChat(tester, fakeClient, group);

      // Four tiles, the last one saying how many more there are.
      expect(find.byKey(const Key('chat-image-3')), findsOneWidget);
      expect(find.byKey(const Key('chat-image-4')), findsNothing);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('My harvest'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-image-1')));
      await tester.pumpAndSettle();

      expect(find.byType(ImageGalleryViewer), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);

      await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.text('3 / 5'), findsOneWidget);
    },
  );

  testWidgets(
    'opening a chat with more history than fits on screen starts scrolled '
    'to the latest message, not the oldest',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final group = _buildGroup(id: 1, name: 'Tomato Growers');
      final fakeClient = FakeApiClient()
        ..groupMessagesResult = PaginatedResponse(
          data: [
            for (var i = 1; i <= 30; i++)
              GroupMessage(
                id: i,
                groupId: 1,
                body: 'Message $i',
                sender: buildFakeUser(id: 2, name: 'Elena'),
                senderIsAdmin: false,
                createdAt: DateTime(2026, 1, 1, 0, i),
              ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 30,
        );

      await _pumpGroupChat(tester, fakeClient, group);

      // 30 short messages don't all fit in a phone-sized viewport at once —
      // if the chat hadn't scrolled to the bottom, only messages from the
      // start of the list would be built and findable here.
      expect(find.text('Message 1'), findsNothing);
      expect(find.text('Message 30'), findsOneWidget);
    },
  );

  testWidgets(
    'swiping a message starts a reply, and sending it quotes the original',
    (tester) async {
      final group = _buildGroup(id: 1, name: 'Tomato Growers');
      final fakeClient = FakeApiClient()
        ..groupMessagesResult = PaginatedResponse(
          data: [
            GroupMessage(
              id: 1,
              groupId: 1,
              body: 'Who has spare seeds?',
              sender: buildFakeUser(id: 2, name: 'Elena'),
              createdAt: DateTime.now(),
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        )
        ..sendGroupMessageResult = GroupMessage(
          id: 5,
          groupId: 1,
          body: 'I do!',
          sender: buildFakeUser(id: 1, name: 'Me'),
          replyToId: 1,
          replyTo: const MessageReply(
            id: 1,
            body: 'Who has spare seeds?',
            senderName: 'Elena',
          ),
          createdAt: DateTime.now(),
        );

      await _pumpGroupChat(tester, fakeClient, group);

      await tester.drag(
        find.byKey(const Key('message-bubble-1')),
        const Offset(120, 0),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('reply-composer-bar')), findsOneWidget);
      expect(find.text('Replying to Elena'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'I do!');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(fakeClient.lastSentGroupMessageReplyToId, 1);
      expect(find.byKey(const Key('reply-composer-bar')), findsNothing);
      // The sent reply shows its quote of the original.
      expect(find.byKey(const Key('reply-quote')), findsOneWidget);
      expect(find.text('Who has spare seeds?'), findsNWidgets(2));
    },
  );

  testWidgets('long-press offers Reply, and the reply bar can be cancelled', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers');
    final fakeClient = FakeApiClient()
      ..groupMessagesResult = PaginatedResponse(
        data: [
          GroupMessage(
            id: 1,
            groupId: 1,
            body: 'Hello',
            sender: buildFakeUser(id: 2, name: 'Elena'),
            createdAt: DateTime.now(),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpGroupChat(tester, fakeClient, group);

    await tester.longPress(find.byKey(const Key('message-bubble-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('report-message')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reply-to-message')));
    await tester.pumpAndSettle();

    expect(find.text('Replying to Elena'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cancel-reply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reply-composer-bar')), findsNothing);
  });

  testWidgets('a reply whose original is gone says it is unavailable', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers');
    final fakeClient = FakeApiClient()
      ..groupMessagesResult = PaginatedResponse(
        data: [
          GroupMessage(
            id: 9,
            groupId: 1,
            body: 'Replying to something',
            replyToId: 3,
            sender: buildFakeUser(id: 2, name: 'Elena'),
            createdAt: DateTime.now(),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpGroupChat(tester, fakeClient, group);

    expect(find.text('Original message unavailable'), findsOneWidget);
  });

  testWidgets(
    'long-press lets you react, and tapping your own reaction removes it',
    (tester) async {
      final group = _buildGroup(id: 1, name: 'Tomato Growers');
      final fakeClient = FakeApiClient()
        ..groupMessagesResult = PaginatedResponse(
          data: [
            GroupMessage(
              id: 1,
              groupId: 1,
              body: 'First harvest!',
              sender: buildFakeUser(id: 2, name: 'Elena'),
              createdAt: DateTime.now(),
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        )
        ..reactionResult = const [
          MessageReaction(emoji: '👍', userIds: [1]),
        ];

      await _pumpGroupChat(tester, fakeClient, group);

      await tester.longPress(find.byKey(const Key('message-bubble-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('react-👍')));
      await tester.pumpAndSettle();

      expect(fakeClient.reactionCalls.last, (1, '👍'));
      expect(find.byKey(const Key('reaction-chip-👍')), findsOneWidget);

      fakeClient.reactionResult = const [];
      await tester.tap(find.byKey(const Key('reaction-chip-👍')));
      await tester.pumpAndSettle();

      expect(fakeClient.reactionCalls.last, (1, null));
      expect(find.byKey(const Key('reaction-chip-👍')), findsNothing);
    },
  );

  testWidgets('a failed reaction is rolled back', (tester) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers');
    final fakeClient = FakeApiClient()
      ..groupMessagesResult = PaginatedResponse(
        data: [
          GroupMessage(
            id: 1,
            groupId: 1,
            body: 'Hi',
            sender: buildFakeUser(id: 2, name: 'Elena'),
            createdAt: DateTime.now(),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      )
      ..reactionError = const ApiException(message: 'No connection');

    await _pumpGroupChat(tester, fakeClient, group);

    await tester.longPress(find.byKey(const Key('message-bubble-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('react-😂')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reaction-chip-😂')), findsNothing);
    expect(find.text('No connection'), findsOneWidget);
  });

  testWidgets('reactions from others arrive live over the channel', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers');
    FakeGroupRealtimeChannel? channel;
    final fakeClient = FakeApiClient()
      ..groupMessagesResult = PaginatedResponse(
        data: [
          GroupMessage(
            id: 1,
            groupId: 1,
            body: 'Hi',
            sender: buildFakeUser(id: 1, name: 'Me'),
            createdAt: DateTime.now(),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpGroupChat(
      tester,
      fakeClient,
      group,
      onChannelCreated: (c) => channel = c,
    );

    channel!.onReactions!(1, const [
      MessageReaction(emoji: '🙏', userIds: [2, 3]),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('🙏 2'), findsOneWidget);
  });

  testWidgets('sending a message calls the API and appears in the thread', (
    tester,
  ) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers');
    final fakeClient = FakeApiClient()
      ..sendGroupMessageResult = GroupMessage(
        id: 5,
        groupId: 1,
        body: 'Anyone tried neem spray?',
        sender: buildFakeUser(id: 1, name: 'Me'),
        senderIsAdmin: false,
        createdAt: DateTime.now(),
      );

    await _pumpGroupChat(tester, fakeClient, group);

    await tester.enterText(find.byType(TextField), 'Anyone tried neem spray?');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(fakeClient.lastSentGroupMessageBody, 'Anyone tried neem spray?');
    expect(find.text('Anyone tried neem spray?'), findsOneWidget);
  });

  testWidgets(
    'a sent message appears instantly, before the server round trip resolves',
    (tester) async {
      final group = _buildGroup(id: 1, name: 'Tomato Growers');
      final fakeClient = _DelayedSendApiClient();

      await _pumpGroupChat(tester, fakeClient, group);

      await tester.enterText(find.byType(TextField), 'Still available?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // The optimistic bubble is already showing — the real request hasn't
      // resolved yet.
      expect(find.text('Still available?'), findsOneWidget);
      expect(find.text('Sending…'), findsOneWidget);

      fakeClient.resolve(
        GroupMessage(
          id: 5,
          groupId: 1,
          body: 'Still available?',
          sender: buildFakeUser(id: 1, name: 'Me'),
          senderIsAdmin: false,
          createdAt: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Still available?'), findsOneWidget);
      expect(find.text('Sending…'), findsNothing);
    },
  );

  testWidgets('does not show a message twice when the realtime echo beats the '
      "send request's own HTTP response", (tester) async {
    final group = _buildGroup(id: 1, name: 'Tomato Growers');
    final fakeClient = _DelayedSendApiClient();
    late FakeGroupRealtimeChannel channel;

    await _pumpGroupChat(
      tester,
      fakeClient,
      group,
      onChannelCreated: (c) => channel = c,
    );

    await tester.enterText(find.byType(TextField), 'On my way!');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    final confirmed = GroupMessage(
      id: 5,
      groupId: 1,
      body: 'On my way!',
      sender: buildFakeUser(id: 1, name: 'Me'),
      senderIsAdmin: false,
      createdAt: DateTime.now(),
    );

    // The realtime broadcast of this exact message arrives before this
    // request's own HTTP response does — a real race with Reverb.
    channel.onMessage?.call(confirmed);
    await tester.pump();
    fakeClient.resolve(confirmed);
    await tester.pumpAndSettle();

    expect(find.text('On my way!'), findsOneWidget);
  });

  testWidgets('shows the real pinned banner with an unpin control for admins', (
    tester,
  ) async {
    final group = _buildGroup(
      id: 1,
      name: 'Tomato Growers',
      myRole: 'admin',
      pinnedMessage: 'Seed swap Saturday at 10 AM.',
    );

    await _pumpGroupChat(tester, FakeApiClient(), group);

    expect(find.textContaining('Seed swap Saturday'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);
  });

  testWidgets('a regular member sees the pinned banner but cannot unpin it', (
    tester,
  ) async {
    final group = _buildGroup(
      id: 1,
      name: 'Tomato Growers',
      myRole: 'member',
      pinnedMessage: 'Seed swap Saturday at 10 AM.',
    );

    await _pumpGroupChat(tester, FakeApiClient(), group);

    expect(find.textContaining('Seed swap Saturday'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets(
    'lays out without overflow at a real phone width (not the wider default test surface)',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final group = _buildGroup(
        id: 1,
        name: 'Urban Fruit & Citrus Growers Community',
        myRole: 'admin',
        membersCount: 4800,
        pinnedMessage:
            'Community seed & scion exchange meetups start this Saturday at 10 AM. Check Events tab.',
      );
      final fakeClient = FakeApiClient()
        ..groupMessagesResult = PaginatedResponse(
          data: [
            GroupMessage(
              id: 1,
              groupId: 1,
              body:
                  'Welcome new growers! Remember that frost danger is mostly past.',
              sender: buildFakeUser(id: 2, name: 'Dr. Aris Thorne'),
              senderIsAdmin: true,
              createdAt: DateTime.now(),
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await _pumpGroupChat(tester, fakeClient, group);

      expect(tester.takeException(), isNull);
    },
  );
}
