import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/post.dart';
import 'package:shobuj_mobile/models/report.dart';
import 'package:shobuj_mobile/providers/auth_providers.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/home/widgets/post_card.dart';
import 'package:shobuj_mobile/screens/profile/blocked_users_screen.dart';
import 'package:shobuj_mobile/screens/profile/privacy_safety_screen.dart';
import 'package:shobuj_mobile/services/api_exception.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Post _post({required int id, required String body, int authorId = 2}) {
  return Post(
    id: id,
    body: body,
    commentsCount: 0,
    likesCount: 0,
    likedByMe: false,
    author: buildFakeUser(id: authorId, name: authorId == 1 ? 'Me' : 'Rina'),
    createdAt: DateTime.now().subtract(const Duration(hours: 1)),
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  FakeApiClient fakeClient,
  Widget home,
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
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();

  return container;
}

FakeApiClient _feedClient() => FakeApiClient();

/// Two posts — one of the signed-in user's own, one of someone else's —
/// rendered the way every post list in the app renders them.
class _PostList extends StatelessWidget {
  const _PostList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          // Screens pass edit/delete only for the signed-in user's own
          // posts, which is what hides the report/block menu.
          PostCard(
            post: _post(id: 1, body: 'My own post', authorId: 1),
            onEdit: () {},
            onDelete: () {},
          ),
          PostCard(post: _post(id: 2, body: "Rina's post")),
        ],
      ),
    );
  }
}

void main() {
  group('reporting', () {
    testWidgets('reporting someone else\'s post files a real report', (
      tester,
    ) async {
      final client = _feedClient();
      await _pump(tester, client, const _PostList());

      await tester.tap(find.byKey(const Key('post-safety-menu-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report post'));
      await tester.pumpAndSettle();

      // Submit stays disabled until a reason is chosen.
      FilledButton submit() =>
          tester.widget<FilledButton>(find.byKey(const Key('report-submit')));
      expect(submit().onPressed, isNull);

      await tester.tap(find.byKey(const Key('report-reason-spam')));
      await tester.pumpAndSettle();
      expect(submit().onPressed, isNotNull);

      await tester.enterText(
        find.byKey(const Key('report-details')),
        'Looks like an ad',
      );
      await tester.tap(find.byKey(const Key('report-submit')));
      await tester.pumpAndSettle();

      expect(client.reportsFiled, hasLength(1));
      expect(client.reportsFiled.single.target, ReportTarget.post);
      expect(client.reportsFiled.single.targetId, 2);
      expect(client.reportsFiled.single.reason, ReportReason.spam);
      expect(client.reportsFiled.single.details, 'Looks like an ad');
      expect(
        find.text('Thanks — our team will review this report.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('report-sheet')), findsNothing);
    });

    testWidgets(
      'a failed report shows the server message and keeps the sheet',
      (tester) async {
        final client = _feedClient()
          ..reportError = const ApiException(
            message: 'You cannot report your own content.',
            statusCode: 422,
          );
        await _pump(tester, client, const _PostList());

        await tester.tap(find.byKey(const Key('post-safety-menu-2')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Report post'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('report-reason-other')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('report-submit')));
        await tester.pumpAndSettle();

        expect(
          find.text('You cannot report your own content.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('report-sheet')), findsOneWidget);
      },
    );

    testWidgets('your own post has no report/block menu', (tester) async {
      await _pump(tester, _feedClient(), const _PostList());

      expect(find.byKey(const Key('post-safety-menu-1')), findsNothing);
      expect(find.byKey(const Key('post-safety-menu-2')), findsOneWidget);
    });
  });

  group('blocking', () {
    testWidgets('blocking an author asks first, then blocks them', (
      tester,
    ) async {
      final client = _feedClient();
      await _pump(tester, client, const _PostList());

      await tester.tap(find.byKey(const Key('post-safety-menu-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block Rina'));
      await tester.pumpAndSettle();

      expect(find.text('Block Rina?'), findsOneWidget);
      expect(client.blockedUserIds, isEmpty);

      await tester.tap(find.byKey(const Key('confirm-block')));
      await tester.pumpAndSettle();

      expect(client.blockedUserIds, [2]);
      expect(find.text('Blocked Rina.'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation blocks nobody', (tester) async {
      final client = _feedClient();
      await _pump(tester, client, const _PostList());

      await tester.tap(find.byKey(const Key('post-safety-menu-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block Rina'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(client.blockedUserIds, isEmpty);
    });

    testWidgets('the blocked users screen lists people and unblocks them', (
      tester,
    ) async {
      final client = FakeApiClient()
        ..blockedUsersResult = [
          buildFakeUser(id: 7, name: 'Karim'),
          buildFakeUser(id: 8, name: 'Nadia'),
        ];
      await _pump(tester, client, const BlockedUsersScreen());

      expect(find.text('Karim'), findsOneWidget);
      expect(find.text('Nadia'), findsOneWidget);

      await tester.tap(find.byKey(const Key('unblock-7')));
      await tester.pumpAndSettle();

      expect(client.unblockedUserIds, [7]);
      expect(find.text('Karim'), findsNothing);
      expect(find.text('Nadia'), findsOneWidget);
    });

    testWidgets('the blocked users screen has an empty state', (tester) async {
      await _pump(tester, FakeApiClient(), const BlockedUsersScreen());

      expect(find.text("You haven't blocked anyone."), findsOneWidget);
    });
  });

  group('deleting your account', () {
    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('delete-account-row')));
      await tester.pumpAndSettle();
    }

    testWidgets('needs a password before it will call the server', (
      tester,
    ) async {
      final client = FakeApiClient();
      await _pump(tester, client, const PrivacySafetyScreen());
      await openDialog(tester);

      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('Enter your password to confirm.'), findsOneWidget);
      expect(client.lastDeletedAccountPassword, isNull);
    });

    testWidgets('a wrong password shows the error and keeps you signed in', (
      tester,
    ) async {
      final client = FakeApiClient()
        ..deleteAccountError = const ApiException(
          message: 'The password is incorrect.',
          statusCode: 422,
        );
      final container = await _pump(
        tester,
        client,
        const PrivacySafetyScreen(),
      );
      await openDialog(tester);

      await tester.enterText(
        find.byKey(const Key('delete-account-password')),
        'wrong',
      );
      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pumpAndSettle();

      expect(find.text('The password is incorrect.'), findsOneWidget);
      expect(container.read(authControllerProvider).valueOrNull, isNotNull);
    });

    testWidgets('the right password deletes the account and signs out', (
      tester,
    ) async {
      final client = FakeApiClient();
      final container = await _pump(
        tester,
        client,
        const PrivacySafetyScreen(),
      );
      await openDialog(tester);

      await tester.enterText(
        find.byKey(const Key('delete-account-password')),
        'correct-horse-9',
      );
      await tester.tap(find.byKey(const Key('delete-account-confirm')));
      await tester.pumpAndSettle();

      expect(client.lastDeletedAccountPassword, 'correct-horse-9');
      expect(container.read(authControllerProvider).valueOrNull, isNull);
    });

    testWidgets('cancelling leaves the account untouched', (tester) async {
      final client = FakeApiClient();
      final container = await _pump(
        tester,
        client,
        const PrivacySafetyScreen(),
      );
      // Nothing on this screen watches the auth provider, so start it (and let
      // its session restore finish) before asserting on it.
      container.listen(authControllerProvider, (_, _) {});
      await tester.pumpAndSettle();
      await openDialog(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(client.lastDeletedAccountPassword, isNull);
      expect(container.read(authControllerProvider).valueOrNull, isNotNull);
    });
  });
}
