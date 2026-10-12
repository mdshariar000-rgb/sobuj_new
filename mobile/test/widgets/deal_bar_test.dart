import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/swap_offer.dart';
import 'package:shobuj_mobile/screens/discovery/widgets/deal_bar.dart';

SwapOffer _offer(
  SwapOfferStatus status, {
  int? quantity,
  TransactionType type = TransactionType.sell,
}) {
  return SwapOffer(
    id: 7,
    status: status,
    requester: AppUser(
      id: 2,
      name: 'Rina',
      ratingAvg: 0,
      createdAt: DateTime(2026, 1, 1),
    ),
    listing: Listing(
      id: 1,
      title: 'Beefsteak Tomato Seeds',
      listingType: 'Seeds',
      transactionType: type,
      status: ListingStatus.active,
      price: 1.55,
      quantity: quantity,
      owner: AppUser(
        id: 1,
        name: 'Foysal',
        ratingAvg: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
      createdAt: DateTime(2026, 1, 1),
    ),
    createdAt: DateTime(2026, 1, 2),
  );
}

class _Calls {
  final list = <(SwapOfferStatus, int?)>[];
  Future<void> call(SwapOfferStatus status, {int? quantitySold}) async =>
      list.add((status, quantitySold));
}

Future<_Calls> _pump(
  WidgetTester tester,
  SwapOffer offer, {
  required bool isSeller,
}) async {
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: DealBar(
          swapOffer: offer,
          isSeller: isSeller,
          onUpdateStatus: calls.call,
        ),
      ),
    ),
  );
  return calls;
}

void main() {
  testWidgets('the seller can accept a new request', (tester) async {
    final calls = await _pump(
      tester,
      _offer(SwapOfferStatus.pending),
      isSeller: true,
    );

    expect(find.textContaining('Rina wants this'), findsOneWidget);
    expect(find.byKey(const Key('deal-decline')), findsOneWidget);

    await tester.tap(find.byKey(const Key('deal-accept')));
    await tester.pumpAndSettle();

    expect(calls.list, [(SwapOfferStatus.accepted, null)]);
  });

  testWidgets('the buyer waits for the seller and can only cancel', (
    tester,
  ) async {
    await _pump(tester, _offer(SwapOfferStatus.pending), isSeller: false);

    expect(find.text('Waiting for Foysal to accept.'), findsOneWidget);
    expect(find.byKey(const Key('deal-accept')), findsNothing);
    expect(find.byKey(const Key('deal-cancel')), findsOneWidget);
  });

  testWidgets('marking a multi-unit deal sold asks the seller how many went', (
    tester,
  ) async {
    final calls = await _pump(
      tester,
      _offer(SwapOfferStatus.accepted, quantity: 10),
      isSeller: true,
    );

    await tester.tap(find.byKey(const Key('deal-complete')));
    await tester.pumpAndSettle();
    expect(find.text('How many were sold?'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('deal-quantity-sold')), '12');
    await tester.tap(find.byKey(const Key('deal-quantity-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number from 1 to 10.'), findsOneWidget);
    expect(calls.list, isEmpty);

    await tester.enterText(find.byKey(const Key('deal-quantity-sold')), '3');
    await tester.tap(find.byKey(const Key('deal-quantity-confirm')));
    await tester.pumpAndSettle();
    expect(calls.list, [(SwapOfferStatus.completed, 3)]);
  });

  testWidgets('the buyer confirms receiving it', (tester) async {
    final calls = await _pump(
      tester,
      _offer(SwapOfferStatus.accepted, quantity: 10),
      isSeller: false,
    );

    expect(find.text('Mark as received'), findsOneWidget);
    await tester.tap(find.byKey(const Key('deal-complete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('deal-confirm')));
    await tester.pumpAndSettle();

    expect(calls.list, [(SwapOfferStatus.completed, null)]);
  });

  testWidgets('a swap listing says swapped, not sold', (tester) async {
    await _pump(
      tester,
      _offer(SwapOfferStatus.accepted, type: TransactionType.swap),
      isSeller: true,
    );
    expect(find.text('Mark as swapped'), findsOneWidget);
  });

  testWidgets('a finished deal has no buttons', (tester) async {
    await _pump(tester, _offer(SwapOfferStatus.completed), isSeller: true);

    expect(find.text('Deal done.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
  });
}
