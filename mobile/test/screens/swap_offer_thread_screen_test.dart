import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/swap_message.dart';
import 'package:shobuj_mobile/models/swap_offer.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/providers/discovery_providers.dart';
import 'package:shobuj_mobile/screens/discovery/swap_offer_thread_screen.dart';
import 'package:shobuj_mobile/services/swap_offer_realtime_channel.dart';

import '../support/fake_api_client.dart';
import '../support/fake_secure_storage_service.dart';

/// Lets a test hold the send request open, so it can assert on what's shown
/// while the request is still in flight — proving the message appears
/// instantly rather than only once the round trip completes.
class _DelayedSendApiClient extends FakeApiClient {
  final _completer = Completer<SwapMessage>();

  @override
  Future<SwapMessage> sendSwapOfferMessage(
    int swapOfferId, {
    String? body,
    File? image,
  }) {
    lastSentSwapOfferMessageBody = body;
    return _completer.future;
  }

  void resolve(SwapMessage message) => _completer.complete(message);
}

class FakeSwapOfferRealtimeChannel extends SwapOfferRealtimeChannel {
  FakeSwapOfferRealtimeChannel() : super(dio: Dio(), swapOfferId: 0);

  @override
  Future<void> connect() async {}

  @override
  Future<void> dispose() async {}
}

SwapOffer _buildOffer({required int id}) {
  return SwapOffer(
    id: id,
    status: SwapOfferStatus.pending,
    listing: Listing(
      id: 1,
      title: 'Heirloom Tomato Seeds',
      listingType: 'Seeds & Scions',
      transactionType: TransactionType.sell,
      status: ListingStatus.active,
      price: 4.5,
      createdAt: DateTime(2026, 1, 1),
    ),
    createdAt: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpThread(
  WidgetTester tester,
  FakeApiClient fakeClient,
  SwapOffer offer, {
  void Function(FakeSwapOfferRealtimeChannel channel)? onChannelCreated,
}) async {
  final fakeStorage = FakeSecureStorageService();
  await fakeStorage.saveToken('existing-token');
  fakeClient.meResult = buildFakeUser(id: 1, name: 'Me');

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(fakeClient),
        secureStorageProvider.overrideWithValue(fakeStorage),
        swapOfferRealtimeChannelProvider.overrideWith((ref, swapOfferId) {
          final channel = FakeSwapOfferRealtimeChannel();
          onChannelCreated?.call(channel);
          return channel;
        }),
      ],
      child: MaterialApp(home: SwapOfferThreadScreen(swapOffer: offer)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'opening a thread with more history than fits on screen starts scrolled '
    'to the latest message, not the oldest',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(390, 844));

      final offer = _buildOffer(id: 1);
      final fakeClient = FakeApiClient()
        ..swapOfferMessagesResult = PaginatedResponse(
          data: [
            for (var i = 1; i <= 30; i++)
              SwapMessage(
                id: i,
                swapOfferId: 1,
                isSystemEvent: false,
                body: 'Message $i',
                sender: buildFakeUser(id: 2, name: 'Sam'),
                createdAt: DateTime(2026, 1, 1, 0, i),
              ),
          ],
          currentPage: 1,
          lastPage: 1,
          total: 30,
        );

      await _pumpThread(tester, fakeClient, offer);

      // 30 short messages don't all fit in a phone-sized viewport at once —
      // if the thread hadn't scrolled to the bottom, only messages from the
      // start of the list would be built and findable here.
      expect(find.text('Message 1'), findsNothing);
      expect(find.text('Message 30'), findsOneWidget);
    },
  );

  testWidgets('sending a message calls the API and appears in the thread', (
    tester,
  ) async {
    final offer = _buildOffer(id: 1);
    final fakeClient = FakeApiClient()
      ..sendSwapOfferMessageResult = SwapMessage(
        id: 5,
        swapOfferId: 1,
        isSystemEvent: false,
        body: 'Is this still available?',
        sender: buildFakeUser(id: 1, name: 'Me'),
        createdAt: DateTime.now(),
      );

    await _pumpThread(tester, fakeClient, offer);

    await tester.enterText(
      find.byType(TextField),
      'Is this still available?',
    );
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(fakeClient.lastSentSwapOfferMessageBody, 'Is this still available?');
    expect(find.text('Is this still available?'), findsOneWidget);
  });

  testWidgets(
    'a sent message appears instantly, before the server round trip resolves',
    (tester) async {
      final offer = _buildOffer(id: 1);
      final fakeClient = _DelayedSendApiClient();

      await _pumpThread(tester, fakeClient, offer);

      await tester.enterText(find.byType(TextField), 'Still interested?');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // The optimistic bubble is already showing — the real request hasn't
      // resolved yet.
      expect(find.text('Still interested?'), findsOneWidget);
      expect(find.text('Sending…'), findsOneWidget);

      fakeClient.resolve(
        SwapMessage(
          id: 5,
          swapOfferId: 1,
          isSystemEvent: false,
          body: 'Still interested?',
          sender: buildFakeUser(id: 1, name: 'Me'),
          createdAt: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Still interested?'), findsOneWidget);
      expect(find.text('Sending…'), findsNothing);
    },
  );

  testWidgets(
    'does not show a message twice when the realtime echo beats the '
    "send request's own HTTP response",
    (tester) async {
      final offer = _buildOffer(id: 1);
      final fakeClient = _DelayedSendApiClient();
      late FakeSwapOfferRealtimeChannel channel;

      await _pumpThread(
        tester,
        fakeClient,
        offer,
        onChannelCreated: (c) => channel = c,
      );

      await tester.enterText(find.byType(TextField), 'On my way!');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      final confirmed = SwapMessage(
        id: 5,
        swapOfferId: 1,
        isSystemEvent: false,
        body: 'On my way!',
        sender: buildFakeUser(id: 1, name: 'Me'),
        createdAt: DateTime.now(),
      );

      // The realtime broadcast of this exact message arrives before this
      // request's own HTTP response does — a real race with Reverb.
      channel.onMessage?.call(confirmed);
      await tester.pump();
      fakeClient.resolve(confirmed);
      await tester.pumpAndSettle();

      expect(find.text('On my way!'), findsOneWidget);
    },
  );
}
