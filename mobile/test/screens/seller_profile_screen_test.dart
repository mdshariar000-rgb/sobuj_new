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
import 'package:shobuj_mobile/screens/discovery/seller_profile_screen.dart';

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

Future<void> _pumpSellerProfile(
  WidgetTester tester,
  FakeApiClient fakeClient, {
  int userId = 7,
}) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  fakeClient.meResult = buildFakeUser(id: 1, name: 'Me');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
      ],
      child: MaterialApp(home: SellerProfileScreen(userId: userId)),
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
      ..homeFeedResult = PaginatedResponse(
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
    expect(find.text('Cherry Tomato Seedlings'), findsOneWidget);
  });

  testWidgets(
    'shows honest empty states when the seller has no posts or listings',
    (tester) async {
      final fakeClient = FakeApiClient()
        ..userProfileResult = buildFakeUser(id: 8, name: 'Tanvir Ahmed');

      await _pumpSellerProfile(tester, fakeClient, userId: 8);

      expect(find.text("Hasn't posted anything yet."), findsOneWidget);
      expect(find.text('No active listings right now.'), findsOneWidget);
    },
  );
}
