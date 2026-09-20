import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/comment.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/post.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/post_providers.dart';
import 'package:shobuj_mobile/screens/home/post_detail_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Post _buildPost({
  int id = 1,
  String body = 'My tomatoes are thriving!',
  int commentsCount = 0,
  int likesCount = 0,
  bool likedByMe = false,
  int authorId = 2,
  String authorName = 'Rina',
}) {
  return Post(
    id: id,
    body: body,
    commentsCount: commentsCount,
    likesCount: likesCount,
    likedByMe: likedByMe,
    author: buildFakeUser(id: authorId, name: authorName),
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  );
}

Future<ProviderContainer> _pumpPostDetail(
  WidgetTester tester,
  FakeApiClient fakeClient,
  Post post,
) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  fakeClient.meResult = buildFakeUser(id: 1, name: 'Me');

  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(fakeClient),
      secureStorageProvider.overrideWithValue(fakeStorage),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: PostDetailScreen(post: post)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('tapping the like button on the detail screen likes the post', (
    tester,
  ) async {
    final post = _buildPost();
    final fakeClient = FakeApiClient()
      ..postCommentsResult = const PaginatedResponse(
        data: [],
        currentPage: 1,
        lastPage: 1,
        total: 0,
      )
      ..likePostResult = _buildPost(likesCount: 1, likedByMe: true);

    await _pumpPostDetail(tester, fakeClient, post);

    await tester.tap(find.byIcon(Icons.favorite_border));
    await tester.pumpAndSettle();

    expect(fakeClient.likedPostId, 1);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets(
    'posting a comment updates the shown count and the originating Home '
    'Feed provider without a manual refresh',
    (tester) async {
      final post = _buildPost();
      final fakeClient = FakeApiClient()
        ..homeFeedResult = PaginatedResponse(
          data: [post],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        )
        ..postCommentsResult = const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        )
        ..createCommentResult = Comment(
          id: 10,
          postId: 1,
          body: 'Nice!',
          author: buildFakeUser(id: 1, name: 'Me'),
          createdAt: DateTime.now(),
        );

      final container = await _pumpPostDetail(tester, fakeClient, post);
      // Seed the Home Feed provider too, as if we navigated in from there —
      // autoDispose providers reset without an active listener, so `listen`
      // (not a one-off `read`) is what keeps this instance alive across the
      // rest of the test, matching how a real widget watching it would.
      container.listen(homeFeedProvider, (previous, next) {});
      await tester.pumpAndSettle();

      expect(find.text('0 comments'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Nice!');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.text('1 comments'), findsOneWidget);
      expect(
        container.read(homeFeedProvider).valueOrNull?.posts.first.commentsCount,
        1,
      );
    },
  );

  testWidgets(
    'tapping Reply on a comment shows a banner and sends reply_to_comment_id',
    (tester) async {
      final post = _buildPost(commentsCount: 1);
      final topLevelComment = Comment(
        id: 5,
        postId: 1,
        body: 'Great progress!',
        author: buildFakeUser(id: 3, name: 'Elena Rostova'),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      final fakeClient = FakeApiClient()
        ..postCommentsResult = PaginatedResponse(
          data: [topLevelComment],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        )
        ..createCommentResult = Comment(
          id: 11,
          postId: 1,
          parentId: 5,
          body: 'Thanks so much!',
          author: buildFakeUser(id: 1, name: 'Me'),
          replyingToName: 'Elena Rostova',
          createdAt: DateTime.now(),
        );

      await _pumpPostDetail(tester, fakeClient, post);

      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();

      expect(find.text('Replying to Elena Rostova'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Thanks so much!');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(fakeClient.lastReplyToCommentId, 5);
      // The reply banner clears after a successful send.
      expect(find.text('Replying to Elena Rostova'), findsNothing);
      // The new reply renders with the bold-name prefix inline with the body.
      expect(
        find.textContaining('Elena Rostova Thanks so much!'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'focusing the comment field scrolls to reveal it above the keyboard',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final post = _buildPost(commentsCount: 20);
      final fakeClient = FakeApiClient()
        ..postCommentsResult = PaginatedResponse(
          data: [
            for (var i = 1; i <= 20; i++)
              Comment(
                id: i,
                postId: 1,
                body: 'Comment $i',
                author: buildFakeUser(id: 2, name: 'Rina'),
                createdAt: DateTime.now().subtract(Duration(minutes: 20 - i)),
              ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 20,
        );

      await _pumpPostDetail(tester, fakeClient, post);

      final controller = tester.widget<ListView>(find.byType(ListView)).controller!;
      // 20 comments plus the post itself overflow a phone-sized viewport —
      // starting scrolled at the top (reading the post first, unlike a
      // chat), so there's real room below to scroll into.
      expect(controller.position.pixels, lessThan(controller.position.maxScrollExtent));

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      expect(controller.position.pixels, controller.position.maxScrollExtent);
    },
  );

  testWidgets(
    "the post owner can delete a comment left by someone else on their own post",
    (tester) async {
      final post = _buildPost(authorId: 1, authorName: 'Me', commentsCount: 1);
      final fakeClient = FakeApiClient()
        ..postCommentsResult = PaginatedResponse(
          data: [
            Comment(
              id: 5,
              postId: 1,
              body: 'A comment from someone else',
              author: buildFakeUser(id: 2, name: 'Rina'),
              createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await _pumpPostDetail(tester, fakeClient, post);

      // Someone else's comment gets a ⋮ menu (Delete/Report/Block) — the post
      // owner's Delete option lives there.
      await tester.tap(find.byKey(const Key('comment-menu-5')));
      await tester.pumpAndSettle();

      expect(find.text('Delete comment'), findsOneWidget);
      expect(find.text('Report comment'), findsOneWidget);

      await tester.tap(find.text('Delete comment'));
      await tester.pumpAndSettle();

      expect(fakeClient.deleteCommentCalled, isTrue);
    },
  );

  testWidgets(
    "a comment's author can delete their own comment even on someone else's post",
    (tester) async {
      final post = _buildPost(authorId: 2, authorName: 'Rina', commentsCount: 1);
      final fakeClient = FakeApiClient()
        ..postCommentsResult = PaginatedResponse(
          data: [
            Comment(
              id: 5,
              postId: 1,
              body: 'My own comment',
              author: buildFakeUser(id: 1, name: 'Me'),
              createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await _pumpPostDetail(tester, fakeClient, post);

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    },
  );

  testWidgets(
    "a comment can't be deleted by someone who is neither its author nor the post owner",
    (tester) async {
      final post = _buildPost(authorId: 3, authorName: 'Someone Else');
      final fakeClient = FakeApiClient()
        ..postCommentsResult = PaginatedResponse(
          data: [
            Comment(
              id: 5,
              postId: 1,
              body: 'Not my comment or my post',
              author: buildFakeUser(id: 2, name: 'Rina'),
              createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await _pumpPostDetail(tester, fakeClient, post);

      expect(find.byIcon(Icons.delete_outline), findsNothing);
    },
  );
}
