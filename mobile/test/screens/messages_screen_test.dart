import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/swap_offer.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/discovery_providers.dart';
import 'package:shobuj_mobile/screens/discovery/messages_screen.dart';
import 'package:shobuj_mobile/screens/discovery/swap_offer_thread_screen.dart';
import 'package:shobuj_mobile/services/swap_offer_realtime_channel.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

/// Never actually opens a socket — see discovery_screen_test.dart for the
/// same reasoning.
class FakeRealtimeChannel extends SwapOfferRealtimeChannel {
  FakeRealtimeChannel() : super(dio: Dio(), swapOfferId: 0);

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {}
}

class MessagesFakeApiClient extends FakeApiClient {
  List<SwapOffer> offers = const [];

  @override
  Future<PaginatedResponse<SwapOffer>> mySwapOffers({int page = 1}) async {
    return PaginatedResponse(
      data: offers,
      currentPage: 1,
      lastPage: 1,
      total: offers.length,
    );
  }
}

Listing _buildListing({
  required int id,
  required String title,
  required AppUser owner,
  double? price,
}) {
  return Listing(
    id: id,
    title: title,
    listingType: ListingType.seedsScions,
    transactionType: price != null
        ? TransactionType.sell
        : TransactionType.swap,
    status: ListingStatus.active,
    price: price,
    owner: owner,
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  final me = AppUser(
    id: 1,
    name: 'Me',
    ratingAvg: 0,
    createdAt: DateTime(2026, 1, 1),
  );
  final seller = AppUser(
    id: 2,
    name: 'Elena Rostova',
    ratingAvg: 0,
    createdAt: DateTime(2026, 1, 1),
  );
  final buyer = AppUser(
    id: 3,
    name: 'Marcus Vance',
    ratingAvg: 0,
    createdAt: DateTime(2026, 1, 1),
  );

  Future<void> pumpMessages(
    WidgetTester tester,
    MessagesFakeApiClient fakeClient,
  ) async {
    final fakeStorage = FakeSecureStorageService();
    await fakeStorage.saveToken('existing-token');
    fakeClient.meResult = me;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(fakeClient),
          secureStorageProvider.overrideWithValue(fakeStorage),
          swapOfferRealtimeChannelProvider.overrideWith(
            (ref, swapOfferId) => FakeRealtimeChannel(),
          ),
        ],
        child: const MaterialApp(home: MessagesScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows conversations with the real last-message preview', (
    tester,
  ) async {
    final fakeClient = MessagesFakeApiClient();
    fakeClient.offers = [
      SwapOffer(
        id: 1,
        status: SwapOfferStatus.pending,
        listing: _buildListing(
          id: 10,
          title: 'Meyer Lemon Rootstock',
          owner: seller,
          price: 28,
        ),
        requester: me,
        lastMessage: SwapOfferLastMessage(
          body: 'Sure! I can meet tomorrow morning.',
          hasImage: false,
          isSystemEvent: false,
          senderId: seller.id,
          createdAt: DateTime(2026, 1, 2, 10, 42),
        ),
        createdAt: DateTime(2026, 1, 2),
      ),
    ];

    await pumpMessages(tester, fakeClient);

    expect(find.text('Elena Rostova'), findsOneWidget);
    expect(
      find.textContaining('Sure! I can meet tomorrow morning.'),
      findsOneWidget,
    );
    expect(find.textContaining('Meyer Lemon Rootstock'), findsOneWidget);
    // The seller sent the last message, so it's the buyer's turn to reply.
    expect(find.widgetWithText(FilledButton, 'Reply'), findsOneWidget);
  });

  testWidgets(
    'Buying/Selling filter chips show real counts and narrow the list',
    (tester) async {
      final fakeClient = MessagesFakeApiClient();
      fakeClient.offers = [
        SwapOffer(
          id: 1,
          status: SwapOfferStatus.pending,
          listing: _buildListing(
            id: 10,
            title: 'Item I Am Buying',
            owner: seller,
          ),
          requester: me,
          createdAt: DateTime(2026, 1, 2),
        ),
        SwapOffer(
          id: 2,
          status: SwapOfferStatus.pending,
          listing: _buildListing(id: 11, title: 'Item I Am Selling', owner: me),
          requester: buyer,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await pumpMessages(tester, fakeClient);

      expect(find.text('Buying (1)'), findsOneWidget);
      expect(find.text('Selling (1)'), findsOneWidget);
      expect(find.textContaining('Item I Am Buying'), findsOneWidget);
      expect(find.textContaining('Item I Am Selling'), findsOneWidget);

      await tester.tap(find.text('Selling (1)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Item I Am Selling'), findsOneWidget);
      expect(find.textContaining('Item I Am Buying'), findsNothing);
    },
  );

  testWidgets('searching filters conversations by listing title', (
    tester,
  ) async {
    final fakeClient = MessagesFakeApiClient();
    fakeClient.offers = [
      SwapOffer(
        id: 1,
        status: SwapOfferStatus.pending,
        listing: _buildListing(
          id: 10,
          title: 'Heirloom Tomato Seeds',
          owner: seller,
        ),
        requester: me,
        createdAt: DateTime(2026, 1, 2),
      ),
      SwapOffer(
        id: 2,
        status: SwapOfferStatus.pending,
        listing: _buildListing(id: 11, title: 'Mint Cuttings', owner: seller),
        requester: me,
        createdAt: DateTime(2026, 1, 1),
      ),
    ];

    await pumpMessages(tester, fakeClient);

    await tester.enterText(find.byType(TextField), 'tomato');
    await tester.pumpAndSettle();

    expect(find.textContaining('Heirloom Tomato Seeds'), findsOneWidget);
    expect(find.textContaining('Mint Cuttings'), findsNothing);
  });

  testWidgets('tapping a conversation opens its thread', (tester) async {
    final fakeClient = MessagesFakeApiClient();
    fakeClient.offers = [
      SwapOffer(
        id: 1,
        status: SwapOfferStatus.pending,
        listing: _buildListing(
          id: 10,
          title: 'Meyer Lemon Rootstock',
          owner: seller,
        ),
        requester: me,
        createdAt: DateTime(2026, 1, 2),
      ),
    ];

    await pumpMessages(tester, fakeClient);

    await tester.tap(find.textContaining('Meyer Lemon Rootstock'));
    await tester.pumpAndSettle();

    expect(find.byType(SwapOfferThreadScreen), findsOneWidget);
  });

  testWidgets(
    'shows a real unread badge on conversations with unread messages',
    (tester) async {
      final fakeClient = MessagesFakeApiClient();
      fakeClient.offers = [
        SwapOffer(
          id: 1,
          status: SwapOfferStatus.pending,
          listing: _buildListing(
            id: 10,
            title: 'Meyer Lemon Rootstock',
            owner: seller,
          ),
          requester: me,
          unreadCount: 3,
          createdAt: DateTime(2026, 1, 2),
        ),
        SwapOffer(
          id: 2,
          status: SwapOfferStatus.pending,
          listing: _buildListing(id: 11, title: 'Mint Cuttings', owner: seller),
          requester: me,
          unreadCount: 0,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];

      await pumpMessages(tester, fakeClient);

      expect(find.text('3'), findsOneWidget);
    },
  );

  testWidgets(
    'lays out without overflow at a real phone width (not the wider default test surface)',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final fakeClient = MessagesFakeApiClient();
      fakeClient.offers = [
        SwapOffer(
          id: 1,
          status: SwapOfferStatus.pending,
          listing: _buildListing(
            id: 10,
            title: 'Meyer Lemon Rootstock',
            owner: seller,
            price: 28,
          ),
          requester: me,
          lastMessage: SwapOfferLastMessage(
            body: 'Sure! I can meet tomorrow morning.',
            hasImage: false,
            isSystemEvent: false,
            senderId: seller.id,
            createdAt: DateTime(2026, 1, 2, 10, 42),
          ),
          createdAt: DateTime(2026, 1, 2),
        ),
      ];

      await pumpMessages(tester, fakeClient);

      // A RenderFlex overflow throws during layout — surviving pumpAndSettle
      // with no caught exception is the actual assertion here. The default
      // 800×600 test surface is wide enough to mask overflows that only show
      // up on a real phone, so this test deliberately uses a narrow one.
      expect(tester.takeException(), isNull);
    },
  );
}
