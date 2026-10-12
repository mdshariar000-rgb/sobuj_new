import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/post.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/feed_marketplace_providers.dart';
import 'package:shobuj_mobile/screens/discovery/seller_profile_screen.dart';
import 'package:shobuj_mobile/services/api_exception.dart';
import 'package:shobuj_mobile/theme/app_theme.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

Post _buildPost({
  required int id,
  required String body,
  required AppUser author,
}) {
  return Post(
    id: id,
    body: body,
    author: author,
    createdAt: DateTime(2026, 1, 1),
  );
}

/// The Listings tab's tappable area (the `Tab` itself doesn't take taps).
final _listingsTab = find.ancestor(
  of: find.byKey(const Key('profile-listings-tab')),
  matching: find.byType(InkWell),
);

Future<void> _pumpSellerProfile(
  WidgetTester tester,
  FakeApiClient fakeClient, {
  int userId = 7,
}) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  fakeClient.meResult = buildFakeUser(id: 1, name: 'Me');
  // A phone-sized screen (390x844), so the header and the tabs below it
  // both fit, as they do on a real device.
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: SellerProfileScreen(userId: userId),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the real name, a real avatar photo, posts, and listings', (
    tester,
  ) async {
    final rina = AppUser(
      id: 7,
      name: 'Rina Chowdhury',
      avatarUrl: 'https://example.com/rina.jpg',
      ratingAvg: 0,
      createdAt: DateTime(2026, 1, 1),
    );

    final fakeClient = FakeApiClient()
      ..userProfileResult = rina
      ..userPostsResult = PaginatedResponse(
        data: [_buildPost(id: 1, body: 'My tomatoes are ripe!', author: rina)],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      )
      ..userListingsResult = PaginatedResponse(
        data: [
          Listing(
            id: 5,
            title: 'Cherry Tomato Seedlings',
            listingType: 'Seeds & Scions',
            transactionType: TransactionType.sell,
            status: ListingStatus.active,
            price: 150,
            owner: rina,
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpSellerProfile(tester, fakeClient, userId: 7);

    // Appears at least once — once as the profile header's name, and again
    // as the author attribution on her own post shown in the Posts section.
    expect(find.text('Rina Chowdhury'), findsWidgets);
    expect(find.byType(CachedNetworkImage), findsWidgets);
    expect(find.text('My tomatoes are ripe!'), findsOneWidget);

    // Listings live in their own tab.
    await tester.tap(_listingsTab);
    await tester.pumpAndSettle();
    expect(find.text('Cherry Tomato Seedlings'), findsOneWidget);
  });

  testWidgets('listings show as a detailed list, not a grid', (tester) async {
    final rina = buildFakeUser(id: 7, name: 'Rina Chowdhury');
    final fakeClient = FakeApiClient()
      ..userProfileResult = rina
      ..userListingsResult = PaginatedResponse(
        data: [
          Listing(
            id: 5,
            title: 'Cherry Tomato Seedlings',
            description: 'Strong plants, ready to pot on.',
            condition: ListingCondition.values.first,
            listingType: 'Live Plants & Saplings',
            transactionType: TransactionType.sell,
            status: ListingStatus.active,
            price: 3,
            averageRating: 4.5,
            reviewsCount: 2,
            owner: rina,
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
          ),
          Listing(
            id: 6,
            title: 'Garlic bulbs',
            listingType: 'Seeds & Scions',
            transactionType: TransactionType.free,
            status: ListingStatus.active,
            owner: rina,
            createdAt: DateTime.now().subtract(const Duration(days: 5)),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pumpSellerProfile(tester, fakeClient, userId: 7);
    await tester.tap(_listingsTab);
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsNothing);
    expect(find.byKey(const Key('profile-listing-5')), findsOneWidget);
    expect(find.byKey(const Key('profile-listing-6')), findsOneWidget);

    // Full-width rows, one under the other.
    final first = tester.getRect(find.byKey(const Key('profile-listing-5')));
    final second = tester.getRect(find.byKey(const Key('profile-listing-6')));
    expect(second.top, greaterThan(first.bottom));
    expect(first.width, greaterThan(300));

    expect(
      find.text(
        'Live Plants & Saplings · ${ListingCondition.values.first.label}',
      ),
      findsOneWidget,
    );
    expect(find.text('Strong plants, ready to pot on.'), findsOneWidget);
    expect(find.text('4.5 (2)'), findsOneWidget);
    expect(find.text('2 days ago'), findsOneWidget);
    expect(find.text('Seeds & Scions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the grower\'s details, stats and trust signals', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..userProfileResult = AppUser(
        id: 7,
        name: 'Rina Chowdhury',
        username: 'rina',
        bio: 'Growing heirloom tomatoes on a Leeds allotment.',
        locationLabel: 'Leeds',
        isVerified: true,
        growingSetup: GrowingSetup.values.first,
        growingInterests: const ['Tomatoes', 'Chillies'],
        ratingAvg: 0,
        postsCount: 12,
        activeListingsCount: 3,
        followersCount: 40,
        followingCount: 9,
        sellerRating: 4.8,
        sellerReviewsCount: 6,
        completedDealsCount: 11,
        createdAt: DateTime(2025, 3, 1),
      );

    await _pumpSellerProfile(tester, fakeClient, userId: 7);

    expect(find.text('@rina'), findsOneWidget);
    expect(
      find.text('Growing heirloom tomatoes on a Leeds allotment.'),
      findsOneWidget,
    );
    expect(find.text('Leeds'), findsOneWidget);
    expect(find.text('Joined Mar 2025'), findsOneWidget);
    expect(find.text('Verified Grower'), findsOneWidget);
    expect(find.text('4.8 · 6 reviews'), findsOneWidget);
    expect(find.text('11 deals completed'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('Tomatoes'), findsOneWidget);
  });

  testWidgets('a new grower with no reviews or deals shows no trust badges', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..userProfileResult = buildFakeUser(id: 8, name: 'Tanvir Ahmed');

    await _pumpSellerProfile(tester, fakeClient, userId: 8);

    expect(find.byKey(const Key('profile-rating-badge')), findsNothing);
    expect(find.byKey(const Key('profile-deals-badge')), findsNothing);
  });

  testWidgets(
    'shows honest empty states when the seller has no posts or listings',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..userProfileResult = buildFakeUser(id: 8, name: 'Tanvir Ahmed');

      await _pumpSellerProfile(tester, fakeClient, userId: 8);

      expect(find.text("Hasn't posted anything yet."), findsOneWidget);
      await tester.tap(_listingsTab);
      await tester.pumpAndSettle();
      expect(find.text('No active listings right now.'), findsOneWidget);
    },
  );

  testWidgets('shows follow counts and a Follow button for another grower', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..userProfileResult = buildFakeUser(
        id: 8,
        name: 'Tanvir Ahmed',
        followersCount: 4,
        followingCount: 2,
        isFollowing: false,
      );

    await _pumpSellerProfile(tester, fakeClient, userId: 8);

    expect(find.text('4'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Following'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Follow'), findsOneWidget);
  });

  testWidgets('tapping Follow calls the API and flips to Following', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..userProfileResult = buildFakeUser(
        id: 8,
        name: 'Tanvir Ahmed',
        followersCount: 4,
        isFollowing: false,
      )
      ..followUserResult = buildFakeUser(
        id: 8,
        name: 'Tanvir Ahmed',
        followersCount: 5,
        isFollowing: true,
      );

    await _pumpSellerProfile(tester, fakeClient, userId: 8);

    await tester.tap(find.widgetWithText(FilledButton, 'Follow'));
    await tester.pumpAndSettle();

    expect(fakeClient.followedUserIds, [8]);
    expect(find.widgetWithText(OutlinedButton, 'Following'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('following someone refreshes Home\'s Picked for you', (
    tester,
  ) async {
    final fakeClient = FakeApiClient()
      ..userProfileResult = buildFakeUser(id: 8, name: 'Tanvir Ahmed')
      ..followUserResult = buildFakeUser(
        id: 8,
        name: 'Tanvir Ahmed',
        isFollowing: true,
      );
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
    // Keep Home's "Picked for you" alive, as the tab shell does behind this
    // screen — it includes new listings from followed growers.
    container.listen(feedMarketplaceProvider, (_, _) {});

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SellerProfileScreen(userId: 8)),
      ),
    );
    await tester.pumpAndSettle();
    final fetchesBefore = fakeClient.feedMarketplaceCalls;

    await tester.tap(find.widgetWithText(FilledButton, 'Follow'));
    await tester.pumpAndSettle();

    expect(fakeClient.feedMarketplaceCalls, greaterThan(fetchesBefore));
  });

  testWidgets('no Follow button on your own profile', (tester) async {
    final fakeClient = FakeApiClient()
      ..userProfileResult = buildFakeUser(id: 1, name: 'Me');

    await _pumpSellerProfile(tester, fakeClient, userId: 1);

    expect(find.widgetWithText(FilledButton, 'Follow'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Following'), findsNothing);
  });

  testWidgets(
    'a blocked grower\'s profile offers Unblock instead of an error',
    (tester) async {
      final rina = buildFakeUser(id: 7, name: 'Rina Chowdhury');
      final fakeClient = FakeApiClient()
        ..blockedUsersResult = [rina]
        // The API hides a blocked user's profile behind a 404.
        ..userProfileError = const ApiException(
          message: 'Not found.',
          statusCode: 404,
        );

      await _pumpSellerProfile(tester, fakeClient);

      expect(find.text("You've blocked Rina Chowdhury"), findsOneWidget);
      expect(find.text('Not found.'), findsNothing);

      await tester.tap(find.byKey(const Key('unblock-profile-button')));
      await tester.pumpAndSettle();

      expect(fakeClient.unblockedUserIds, [7]);
      expect(find.text('Unblocked Rina Chowdhury.'), findsOneWidget);
    },
  );

  testWidgets(
    'a profile that fails to load for another reason shows the error',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..userProfileError = const ApiException(
          message: 'Not found.',
          statusCode: 404,
        );

      await _pumpSellerProfile(tester, fakeClient);

      expect(find.text('Not found.'), findsOneWidget);
      expect(find.byKey(const Key('unblock-profile-button')), findsNothing);
    },
  );
}
