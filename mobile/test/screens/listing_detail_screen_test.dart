import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/listing_review.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/discovery/listing_detail_screen.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

AppUser _buildUser({required int id, required String name}) {
  return AppUser(
    id: id,
    name: name,
    ratingAvg: 0,
    createdAt: DateTime(2026, 1, 1),
  );
}

Listing _buildListing({
  required int id,
  required AppUser owner,
  ListingStatus status = ListingStatus.active,
  bool? canReview,
}) {
  return Listing(
    id: id,
    title: 'Heirloom Tomato Seeds',
    listingType: 'Seeds & Scions',
    transactionType: TransactionType.sell,
    status: status,
    price: 3.5,
    owner: owner,
    canReview: canReview,
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpListingDetail(
  WidgetTester tester,
  FakeApiClient fakeClient,
  Listing listing, {
  int meId = 1,
}) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  fakeClient.meResult = _buildUser(id: meId, name: 'Me');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
      child: MaterialApp(home: ListingDetailScreen(listing: listing)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the average rating and existing reviews', (tester) async {
    final owner = _buildUser(id: 99, name: 'A Grower');
    final listing = _buildListing(id: 1, owner: owner);
    final fakeClient = FakeApiClient()
      ..listingReviewsResult = PaginatedResponse(
        data: [
          ListingReview(
            id: 1,
            listingId: 1,
            rating: 2,
            comment: 'Seeds arrived late.',
            reviewer: _buildUser(id: 2, name: 'Carlos Mendoza'),
            createdAt: DateTime(2026, 2, 1),
          ),
          ListingReview(
            id: 2,
            listingId: 1,
            rating: 4,
            comment: 'Great germination rate!',
            reviewer: _buildUser(id: 3, name: 'Priya Nair'),
            createdAt: DateTime(2026, 2, 2),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 2,
      );

    await _pumpListingDetail(tester, fakeClient, listing);

    expect(find.text('Reviews'), findsOneWidget);
    expect(find.text('3.0 (2 reviews)'), findsOneWidget);
    expect(find.text('Carlos Mendoza'), findsOneWidget);
    expect(find.text('Seeds arrived late.'), findsOneWidget);
    expect(find.text('Priya Nair'), findsOneWidget);
    expect(find.text('Great germination rate!'), findsOneWidget);
  });

  testWidgets('shows an empty state when a listing has no reviews yet', (
    tester,
  ) async {
    final owner = _buildUser(id: 99, name: 'A Grower');
    final listing = _buildListing(id: 1, owner: owner);
    await _pumpListingDetail(tester, FakeApiClient(), listing);

    expect(
      find.text('No reviews yet — be the first to leave one.'),
      findsOneWidget,
    );
  });

  testWidgets('without a completed deal there is no Write a Review button, '
      'just a note', (tester) async {
    final owner = _buildUser(id: 99, name: 'A Grower');
    final listing = _buildListing(id: 1, owner: owner);
    final fakeClient = FakeApiClient()
      ..listingResult = _buildListing(id: 1, owner: owner, canReview: false);

    await _pumpListingDetail(tester, fakeClient, listing);

    expect(find.byKey(const Key('write-review-button')), findsNothing);
    expect(find.byKey(const Key('review-after-deal-hint')), findsOneWidget);
  });

  testWidgets('a completed listing says so and can no longer be contacted', (
    tester,
  ) async {
    final owner = _buildUser(id: 99, name: 'A Grower');
    final listing = _buildListing(id: 1, owner: owner);
    final fakeClient = FakeApiClient()
      ..listingResult = _buildListing(
        id: 1,
        owner: owner,
        status: ListingStatus.completed,
      );

    await _pumpListingDetail(tester, fakeClient, listing);

    expect(
      find.byKey(const Key('listing-availability-banner')),
      findsOneWidget,
    );
    final cta = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('listing-cta')),
    );
    expect(cta.onPressed, isNull);
    expect(find.text('No longer available'), findsOneWidget);
  });

  testWidgets('a reserved listing shows the reserved banner', (tester) async {
    final owner = _buildUser(id: 99, name: 'A Grower');
    final listing = _buildListing(id: 1, owner: owner);
    final fakeClient = FakeApiClient()
      ..listingResult = _buildListing(
        id: 1,
        owner: owner,
        status: ListingStatus.reserved,
      );

    await _pumpListingDetail(tester, fakeClient, listing);

    expect(find.textContaining('Reserved'), findsOneWidget);
    final cta = tester.widget<ButtonStyleButton>(
      find.byKey(const Key('listing-cta')),
    );
    expect(cta.onPressed, isNotNull);
  });

  testWidgets('hides the Write a Review button on your own listing', (
    tester,
  ) async {
    final me = _buildUser(id: 1, name: 'Me');
    final listing = _buildListing(id: 1, owner: me);
    await _pumpListingDetail(tester, FakeApiClient(), listing, meId: 1);

    expect(find.byKey(const Key('write-review-button')), findsNothing);
  });

  testWidgets(
    'writing a review picks a star rating and comment, then calls the API',
    (tester) async {
      final owner = _buildUser(id: 99, name: 'A Grower');
      final listing = _buildListing(id: 1, owner: owner);
      final fakeClient = FakeApiClient()
        // The full fetch says this user completed a deal for it.
        ..listingResult = _buildListing(id: 1, owner: owner, canReview: true)
        ..submitListingReviewResult = ListingReview(
          id: 5,
          listingId: 1,
          rating: 4,
          comment: 'Healthy cuttings, great packaging.',
          reviewer: _buildUser(id: 1, name: 'Me'),
          createdAt: DateTime(2026, 3, 1),
        );

      await _pumpListingDetail(tester, fakeClient, listing);

      await tester.ensureVisible(find.byKey(const Key('write-review-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('write-review-button')));
      await tester.pumpAndSettle();

      expect(find.text('Write a Review'), findsWidgets);

      await tester.tap(find.byKey(const Key('star-rating-input-4')));
      await tester.enterText(
        find.byType(TextField),
        'Healthy cuttings, great packaging.',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Submit Review'));
      await tester.pumpAndSettle();

      expect(fakeClient.lastSubmitListingReviewRating, 4);
      expect(
        fakeClient.lastSubmitListingReviewComment,
        'Healthy cuttings, great packaging.',
      );
      // The sheet closes and the new review appears in the list.
      expect(find.text('Healthy cuttings, great packaging.'), findsOneWidget);
      expect(find.text('Edit Review'), findsOneWidget);
    },
  );

  testWidgets('the listing owner can delete a review left on their listing', (
    tester,
  ) async {
    final owner = _buildUser(id: 1, name: 'Me');
    final listing = _buildListing(id: 1, owner: owner);
    final fakeClient = FakeApiClient()
      ..listingReviewsResult = PaginatedResponse(
        data: [
          ListingReview(
            id: 7,
            listingId: 1,
            rating: 1,
            comment: 'Not what I expected.',
            reviewer: _buildUser(id: 2, name: 'Carlos Mendoza'),
            createdAt: DateTime(2026, 2, 1),
          ),
        ],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );

    await _pumpListingDetail(tester, fakeClient, listing, meId: 1);

    await tester.ensureVisible(find.byKey(const Key('delete-review-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-review-button')));
    await tester.pumpAndSettle();

    expect(fakeClient.deleteListingReviewCalled, isTrue);
    expect(fakeClient.lastDeletedListingReviewId, 7);
    expect(find.text('Not what I expected.'), findsNothing);
  });

  testWidgets('the seller gets Edit / Mark sold / Delete instead of chat', (
    tester,
  ) async {
    final me = _buildUser(id: 1, name: 'Me');
    final listing = _buildListing(id: 5, owner: me);
    final fakeClient = FakeApiClient()
      ..listingResult = listing
      ..updateListingResult = _buildListing(
        id: 5,
        owner: me,
        status: ListingStatus.completed,
      );

    await _pumpListingDetail(tester, fakeClient, listing, meId: 1);

    expect(find.byKey(const Key('listing-cta')), findsNothing);
    expect(find.byKey(const Key('owner-edit')), findsOneWidget);
    expect(find.byKey(const Key('owner-delete')), findsOneWidget);

    await tester.tap(find.byKey(const Key('owner-toggle-sold')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('owner-action-confirm')));
    await tester.pumpAndSettle();

    expect(fakeClient.lastUpdatedListingStatus, ListingStatus.completed);
    // Now sold, the same button offers to put it back.
    expect(find.text('Put back'), findsOneWidget);
  });

  testWidgets('the seller can delete their listing after confirming', (
    tester,
  ) async {
    final me = _buildUser(id: 1, name: 'Me');
    final listing = _buildListing(id: 6, owner: me);
    final fakeClient = FakeApiClient()..listingResult = listing;

    await _pumpListingDetail(tester, fakeClient, listing, meId: 1);

    await tester.tap(find.byKey(const Key('owner-delete')));
    await tester.pumpAndSettle();
    expect(find.text('Delete "Heirloom Tomato Seeds"?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('owner-action-confirm')));
    await tester.pumpAndSettle();

    expect(fakeClient.deletedListingId, 6);
  });
}
