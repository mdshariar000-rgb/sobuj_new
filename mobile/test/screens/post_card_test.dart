import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/post.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/home/widgets/post_card.dart';

import '../support/fake_api_client.dart';

/// Renders [posts] the way every post list in the app does (group threads,
/// profiles, post detail).
Future<void> _pumpPosts(WidgetTester tester, List<Post> posts) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(FakeApiClient())],
      child: MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [for (final post in posts) PostCard(post: post)],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a post from a group says which group it is from', (
    tester,
  ) async {
    await _pumpPosts(tester, [
      Post.fromJson({
        'id': 1,
        'group_id': 3,
        'group': {'id': 3, 'name': 'Tomato Growers'},
        'body': 'Group harvest photos',
        'category': 'General',
        'approval_status': 'approved',
        'created_at': '2026-09-30T10:00:00Z',
      }),
    ]);

    expect(find.text('in Tomato Growers'), findsOneWidget);
    expect(find.byKey(const Key('post-group-label')), findsOneWidget);
  });

  group('sharing', () {
    Map<String, dynamic> originalJson({String? visibility, int? groupId}) => {
      'id': 5,
      'group_id': groupId,
      if (groupId != null)
        'group': {
          'id': groupId,
          'name': 'Tomato Growers',
          'visibility': visibility,
        },
      'body': 'Look at my tomatoes',
      'category': 'General',
      'approval_status': 'approved',
      'can_share': visibility != 'private',
      'shares_count': 2,
      'author': {
        'id': 7,
        'name': 'Karim',
        'email': 'k@example.com',
        'rating_avg': 0,
        'created_at': '2026-01-01T00:00:00Z',
      },
      'created_at': '2026-09-30T10:00:00Z',
    };

    testWidgets('a public group post can be shared to other apps', (
      tester,
    ) async {
      final post = Post.fromJson({
        ...originalJson(groupId: 3, visibility: 'public'),
        'can_share': true,
      });

      await _pumpPosts(tester, [post]);

      expect(find.text('Look at my tomatoes'), findsOneWidget);
      expect(find.byKey(const Key('post-share-5')), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('a private group post has no share button', (tester) async {
      final fakeClient = FakeApiClient()
        ..userPostsResult = PaginatedResponse(
          data: [
            Post.fromJson(originalJson(groupId: 3, visibility: 'private')),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 1,
        );

      await _pumpPosts(tester, fakeClient.userPostsResult!.data);

      expect(find.text('Look at my tomatoes'), findsOneWidget);
      expect(find.byKey(const Key('post-share-5')), findsNothing);
    });
  });
}
