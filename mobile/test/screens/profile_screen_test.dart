import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/post.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/profile/edit_profile_screen.dart';
import 'package:shobuj_mobile/screens/profile/privacy_safety_screen.dart';
import 'package:shobuj_mobile/screens/discovery/listing_detail_screen.dart';
import 'package:shobuj_mobile/screens/profile/profile_screen.dart';
import 'package:shobuj_mobile/theme/app_theme.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

AppUser _buildUser({
  String? username,
  String? bio,
  String? locationLabel,
  int? postsCount,
  int? activeListingsCount,
  int? followersCount,
  int? followingCount,
  bool isVerified = false,
}) {
  return AppUser(
    id: 1,
    name: 'Maya Lin',
    email: 'maya@example.com',
    username: username,
    bio: bio,
    locationLabel: locationLabel,
    isVerified: isVerified,
    ratingAvg: 0,
    postsCount: postsCount,
    activeListingsCount: activeListingsCount,
    followersCount: followersCount,
    followingCount: followingCount,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required FakeApiClient fakeClient,
}) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  // Taller than the default 800x600 test surface, so the header (with its
  // settings rows) and the tabs below it both fit, as on a real device.
  tester.view.physicalSize = const Size(800, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
      // The real theme, so layout bugs it causes (full-width buttons in a
      // Row) show up here too.
      child: MaterialApp(theme: AppTheme.light(), home: const ProfileScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'shows only real profile fields, no fabricated Connections stat',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..meResult = _buildUser(
          username: 'mayagrows',
          bio: 'Backyard grower',
          locationLabel: 'Napa Valley, CA',
          postsCount: 3,
          activeListingsCount: 2,
          isVerified: true,
        );

      await _pump(tester, fakeClient: fakeClient);

      expect(find.text('Maya Lin'), findsOneWidget);
      expect(find.text('@mayagrows'), findsOneWidget);
      expect(find.text('Verified Grower'), findsOneWidget);
      expect(find.text('Napa Valley, CA'), findsOneWidget);
      expect(find.text('My Posts'), findsOneWidget);
      expect(find.text('My Listings'), findsOneWidget);
      // "3"/"2" appear twice each — once in the stats row, once in the tab
      // pill badge — both showing the same real count.
      expect(find.text('3'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.textContaining('Connections'), findsNothing);
      expect(find.textContaining('Saved Diagnoses'), findsNothing);
    },
  );

  testWidgets('tapping Edit Profile opens the edit screen', (tester) async {
    final fakeClient = FakeApiClient()..meResult = _buildUser();
    await _pump(tester, fakeClient: fakeClient);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(EditProfileScreen), findsOneWidget);
  });

  testWidgets(
    'Profile no longer offers Manage Subscription (Agri-AI removed)',
    (tester) async {
      final fakeClient = FakeApiClient()..meResult = _buildUser();
      await _pump(tester, fakeClient: fakeClient);

      expect(find.text('Manage Subscription'), findsNothing);
    },
  );

  testWidgets(
    'tapping Privacy & Safety opens the screen where blocked users are managed',
    (tester) async {
      final fakeClient = FakeApiClient()..meResult = _buildUser();
      await _pump(tester, fakeClient: fakeClient);

      await tester.tap(find.byKey(const Key('privacy-safety-row')));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacySafetyScreen), findsOneWidget);
      expect(find.text('Blocked users'), findsOneWidget);
    },
  );

  testWidgets('My Posts tab shows general and group posts, labelled', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..meResult = _buildUser(postsCount: 1)
      ..userPostsResult = PaginatedResponse(
        data: [
          Post(
            id: 10,
            body: 'My tomatoes are thriving!',
            author: _buildUser(),
            createdAt: DateTime(2026, 1, 1),
          ),
          Post(
            id: 11,
            body: 'Anyone swapping chilli seeds?',
            author: _buildUser(),
            groupId: 4,
            groupName: 'Leeds Allotments',
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pump(tester, fakeClient: fakeClient);
    await tester.dragUntilVisible(
      find.text('My tomatoes are thriving!'),
      find.byType(TabBarView),
      const Offset(0, -200),
    );

    expect(find.text('My tomatoes are thriving!'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Anyone swapping chilli seeds?'),
      find.byType(TabBarView),
      const Offset(0, -200),
    );
    expect(find.textContaining('in Leeds Allotments'), findsOneWidget);
    // The Groups nudge is only for an empty list.
    expect(find.text('Post in a group'), findsNothing);
  });

  testWidgets('an empty My Posts tab points to Groups', (tester) async {
    final fakeClient = FakeApiClient()..meResult = _buildUser(postsCount: 0);

    await _pump(tester, fakeClient: fakeClient);
    await tester.dragUntilVisible(
      find.text('Post in a group'),
      find.byType(TabBarView),
      const Offset(0, -200),
    );

    expect(find.text("You haven't posted anything yet."), findsOneWidget);
    expect(find.text('Post in a group'), findsOneWidget);
  });

  testWidgets('My Listings tab shows real listings with view counts', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..meResult = _buildUser(activeListingsCount: 1)
      ..myListingsResult = PaginatedResponse(
        data: [
          Listing(
            id: 5,
            title: 'Heirloom Tomato Seeds',
            listingType: 'Seed',
            transactionType: TransactionType.sell,
            status: ListingStatus.active,
            price: 4.5,
            viewsCount: 12,
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pump(tester, fakeClient: fakeClient);
    await tester.tap(find.textContaining('My Listings'));
    await tester.pumpAndSettle();

    expect(find.text('Heirloom Tomato Seeds'), findsOneWidget);
    expect(find.text('12 views'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Manage'), findsOneWidget);
  });

  testWidgets('tapping a row in My Listings opens the listing', (tester) async {
    final listing = Listing(
      id: 5,
      title: 'Heirloom Tomato Seeds',
      listingType: 'Seed',
      transactionType: TransactionType.sell,
      status: ListingStatus.active,
      price: 4.5,
      viewsCount: 12,
      createdAt: DateTime(2026, 1, 1),
    );
    final fakeClient = FakeApiClient()
      ..meResult = _buildUser(activeListingsCount: 1)
      ..listingResult = listing
      ..myListingsResult = PaginatedResponse(
        data: [listing],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pump(tester, fakeClient: fakeClient);
    await tester.tap(find.textContaining('My Listings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12 views'));
    await tester.pumpAndSettle();

    expect(find.byType(ListingDetailScreen), findsOneWidget);
  });

  testWidgets('tapping the Followers count opens the followers list', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..meResult = _buildUser(followersCount: 2, followingCount: 5)
      ..userFollowersResult = [buildFakeUser(id: 2, name: 'Karim Hossain')];

    await _pump(tester, fakeClient: fakeClient);

    expect(find.text('2'), findsWidgets);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('5'), findsWidgets);
    expect(find.text('Following'), findsOneWidget);

    await tester.tap(find.text('Followers'));
    await tester.pumpAndSettle();

    expect(find.text('Karim Hossain'), findsOneWidget);
  });

  testWidgets(
    'lays out without overflow at a real phone width (not the wider default test surface)',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final fakeClient = FakeApiClient()
        ..meResult = _buildUser(
          username: 'mayagrows',
          bio:
              'A very long bio that could wrap across several lines to '
              'exercise narrow-width layout behavior on the profile header.',
          locationLabel: 'Napa Valley, California, United States',
          postsCount: 25,
          activeListingsCount: 6,
          isVerified: true,
        );

      await _pump(tester, fakeClient: fakeClient);

      expect(tester.takeException(), isNull);
    },
  );
}
