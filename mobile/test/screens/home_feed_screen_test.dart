import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/post.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/home/home_feed_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Post _buildPost({
  required int id,
  required String body,
  int authorId = 2,
  String authorName = 'Rina',
  int commentsCount = 0,
  int likesCount = 0,
  bool likedByMe = false,
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

Future<void> _pumpHomeFeed(
  WidgetTester tester,
  FakeApiClient fakeClient, {
  int currentUserId = 1,
}) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  fakeClient.meResult = buildFakeUser(id: currentUserId, name: 'Me');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
      child: const MaterialApp(home: HomeFeedScreen()),
    ),
  );
  await tester.pumpAndSettle();
  // The redesigned Home screen leads with a tall hero header, diagnostics
  // card, AI banner and filter chips before the feed itself — scroll past
  // them so post content (built lazily by the sliver list) actually exists
  // in the tree for finders to see.
  await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows posts returned by the API', (tester) async {
    final fakeClient = FakeApiClient()
      ..homeFeedResult = PaginatedResponse(
        data: [
          _buildPost(id: 1, body: 'My tomatoes are thriving this week!'),
          _buildPost(id: 2, body: 'Anyone dealing with aphids on basil?'),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pumpHomeFeed(tester, fakeClient);

    expect(find.text('My tomatoes are thriving this week!'), findsOneWidget);
    expect(find.text('Anyone dealing with aphids on basil?'), findsOneWidget);
    expect(find.text('Rina'), findsNWidgets(2));
  });

  testWidgets('shows an empty state when there are no posts', (tester) async {
    await _pumpHomeFeed(tester, FakeApiClient());

    expect(find.text('Your feed is empty'), findsOneWidget);
  });

  testWidgets('creating a post adds it to the top of the feed', (tester) async {
    final fakeClient = FakeApiClient()
      ..homeFeedResult = PaginatedResponse(
        data: [_buildPost(id: 1, body: 'Existing post')],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      )
      ..createPostResult = _buildPost(
        id: 2,
        body: 'Fresh basil ready to swap',
        authorId: 1,
        authorName: 'Me',
      );

    await _pumpHomeFeed(tester, fakeClient);

    await tester.tap(find.byIcon(Icons.camera_alt));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Fresh basil ready to swap');
    await tester.tap(find.widgetWithText(FilledButton, 'Post'));
    await tester.pumpAndSettle();

    expect(find.text('Fresh basil ready to swap'), findsOneWidget);
    expect(find.text('Existing post'), findsOneWidget);
  });

  testWidgets('deleting your own post removes it from the feed', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..homeFeedResult = PaginatedResponse(
        data: [
          _buildPost(id: 1, body: 'My own post', authorId: 1, authorName: 'Me'),
          _buildPost(id: 2, body: 'Someone else\'s post'),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pumpHomeFeed(tester, fakeClient);

    expect(find.text('My own post'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_horiz));
    await tester.pumpAndSettle();

    expect(find.text('My own post'), findsNothing);
    expect(find.text('Someone else\'s post'), findsOneWidget);
    expect(fakeClient.deletePostCalled, isTrue);
  });

  testWidgets(
    'tapping the like button likes a post and updates the count instantly',
    (tester) async {
      final post = _buildPost(id: 1, body: 'My tomatoes are thriving!');
      final fakeClient = FakeApiClient()
        ..homeFeedResult = PaginatedResponse(
          data: [post],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        )
        ..likePostResult = _buildPost(
          id: 1,
          body: 'My tomatoes are thriving!',
          likesCount: 1,
          likedByMe: true,
        );

      await _pumpHomeFeed(tester, fakeClient);

      expect(find.text('0'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(fakeClient.likedPostId, 1);
      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the search icon reveals a search field that debounces then '
    'calls the API with the term',
    (tester) async {
      final fakeStorage = FakeSecureStorageService();
      await fakeStorage.saveToken('existing-token');
      final fakeClient = FakeApiClient()
        ..meResult = buildFakeUser(id: 1, name: 'Me')
        ..homeFeedResult = PaginatedResponse(
          data: [_buildPost(id: 1, body: 'My tomatoes are thriving!')],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            secureStorageProvider.overrideWithValue(fakeStorage),
          ],
          child: const MaterialApp(home: HomeFeedScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Initial load happens with no search term.
      expect(fakeClient.lastHomeFeedSearch, isNull);

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(find.text('Search posts or growers...'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'tomato');
      await tester.pump(const Duration(milliseconds: 200));
      expect(fakeClient.lastHomeFeedSearch, isNot('tomato'));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(fakeClient.lastHomeFeedSearch, 'tomato');
    },
  );

  testWidgets(
    'tapping the Disease Alerts/Harvests chips refetches with that real '
    'category, and Recent clears it back to every category',
    (tester) async {
      final fakeStorage = FakeSecureStorageService();
      await fakeStorage.saveToken('existing-token');
      final fakeClient = FakeApiClient()
        ..meResult = buildFakeUser(id: 1, name: 'Me')
        ..homeFeedResult = PaginatedResponse(
          data: [_buildPost(id: 1, body: 'My tomatoes are thriving!')],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            apiClientProvider.overrideWithValue(fakeClient),
            secureStorageProvider.overrideWithValue(fakeStorage),
          ],
          child: const MaterialApp(home: HomeFeedScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();

      expect(fakeClient.lastHomeFeedCategory, isNull);

      await tester.tap(find.text('Disease Alert'));
      await tester.pumpAndSettle();
      expect(fakeClient.lastHomeFeedCategory, 'Disease Alert');

      await tester.tap(find.text('Harvest'));
      await tester.pumpAndSettle();
      expect(fakeClient.lastHomeFeedCategory, 'Harvest');

      await tester.tap(find.text('Recent'));
      await tester.pumpAndSettle();
      expect(fakeClient.lastHomeFeedCategory, isNull);
    },
  );

  testWidgets(
    'picking a category in the composer sends that real category with the '
    'new post',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..homeFeedResult = PaginatedResponse(
          data: const [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        )
        ..createPostResult = _buildPost(
          id: 2,
          body: 'Brown spots on my tomato leaves',
          authorId: 1,
          authorName: 'Me',
        );

      await _pumpHomeFeed(tester, fakeClient);

      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Brown spots on my tomato leaves',
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Disease Alert'));
      await tester.tap(find.widgetWithText(FilledButton, 'Post'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastCreatePostCategory, 'Disease Alert');
    },
  );

  testWidgets(
    'leaving the composer category untouched sends no category, letting the '
    'backend apply its own real default',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..homeFeedResult = PaginatedResponse(
          data: const [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        )
        ..createPostResult = _buildPost(
          id: 2,
          body: 'Just enjoying the garden today',
          authorId: 1,
          authorName: 'Me',
        );

      await _pumpHomeFeed(tester, fakeClient);

      await tester.tap(find.byIcon(Icons.camera_alt));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField),
        'Just enjoying the garden today',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Post'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastCreatePostCategory, isNull);
    },
  );

  testWidgets('unliking a post calls unlikePost and decrements the count', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..homeFeedResult = PaginatedResponse(
        data: [
          _buildPost(
            id: 1,
            body: 'Already liked this one',
            likesCount: 3,
            likedByMe: true,
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      )
      ..unlikePostResult = _buildPost(
        id: 1,
        body: 'Already liked this one',
        likesCount: 2,
      );

    await _pumpHomeFeed(tester, fakeClient);

    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite));
    await tester.pumpAndSettle();

    expect(fakeClient.unlikedPostId, 1);
    expect(find.text('2'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });
}
