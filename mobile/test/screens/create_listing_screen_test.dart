import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/listing_photo.dart';
import 'package:shobuj_mobile/providers/core_providers.dart';
import 'package:shobuj_mobile/screens/discovery/create_listing_screen.dart';

import '../support/fake_api_client.dart';

Future<void> _pump(WidgetTester tester, ListingFormMode mode) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(FakeApiClient())],
      child: MaterialApp(home: CreateListingScreen(mode: mode)),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submit(WidgetTester tester) async {
  final submit = find.byKey(const Key('create-listing-submit'));
  await tester.ensureVisible(submit);
  await tester.pumpAndSettle();
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the Sell form has the seven numbered fields and requires them', (
    tester,
  ) async {
    await _pump(tester, ListingFormMode.sell);

    expect(find.text('Sell an Item'), findsOneWidget);
    for (final label in [
      '1. Title of item ',
      '2. Images ',
      '3. Description of the item ',
      '4. Category ',
      '5. Price per unit (£) ',
      '6. Quantity ',
      '7. Contact Seller ',
    ]) {
      expect(find.textContaining(label, findRichText: true), findsOneWidget);
    }
    expect(find.text('0/500'), findsOneWidget);

    await _submit(tester);

    expect(find.text('Enter a title.'), findsOneWidget);
    expect(find.text('Add at least one photo.'), findsOneWidget);
    expect(find.text('Add a short description.'), findsOneWidget);
    expect(find.text('Select a category.'), findsOneWidget);
    expect(find.text('Enter a price.'), findsOneWidget);
    expect(find.text('Enter a quantity.'), findsOneWidget);
    expect(find.text('Enter a phone number or email.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the contact must be a phone number or an email', (tester) async {
    await _pump(tester, ListingFormMode.sell);

    final contact = find.byKey(const Key('listing-contact-field'));
    await tester.ensureVisible(contact);
    await tester.enterText(contact, 'call me');
    await _submit(tester);
    expect(find.text('Enter a valid phone number or email.'), findsOneWidget);

    await tester.enterText(contact, '07700 900123');
    await _submit(tester);
    expect(find.text('Enter a valid phone number or email.'), findsNothing);

    await tester.enterText(contact, 'grower@example.com');
    await _submit(tester);
    expect(find.text('Enter a valid phone number or email.'), findsNothing);
  });

  testWidgets('the quantity stepper counts up from 1', (tester) async {
    await _pump(tester, ListingFormMode.sell);

    final up = find.byIcon(Icons.keyboard_arrow_up);
    await tester.ensureVisible(up);
    await tester.tap(up);
    await tester.tap(up);
    await tester.pump();

    final field = tester.widget<TextFormField>(
      find.byKey(const Key('listing-quantity-field')),
    );
    expect(field.controller!.text, '2');
  });

  testWidgets('the Swap form asks what you want instead of price/quantity', (
    tester,
  ) async {
    await _pump(tester, ListingFormMode.swap);

    expect(find.text('Swap an Item'), findsOneWidget);
    expect(find.text('Exchange with another item'), findsOneWidget);
    expect(
      find.textContaining(
        '6. What would you like to swap for? ',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('listing-price-field')), findsNothing);
    expect(find.byKey(const Key('listing-quantity-field')), findsNothing);
    expect(find.byKey(const Key('listing-contact-field')), findsNothing);

    await _submit(tester);
    expect(find.text('Say what you would like in exchange.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing fills the form in and saves only the changes', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final listing = Listing(
      id: 9,
      title: 'Basil Plant',
      description: 'Healthy basil',
      listingType: 'Seeds & Scions',
      transactionType: TransactionType.sell,
      status: ListingStatus.active,
      price: 3,
      quantity: 6,
      contact: '07700 900123',
      photos: const [
        ListingPhoto(id: 41, url: 'https://example.com/a.jpg', sortOrder: 0),
        ListingPhoto(id: 42, url: 'https://example.com/b.jpg', sortOrder: 1),
      ],
      createdAt: DateTime(2026, 1, 1),
    );
    final fakeClient = FakeApiClient()..updateListingResult = listing;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(fakeClient)],
        child: MaterialApp(home: CreateListingScreen(editing: listing)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit Item'), findsOneWidget);
    expect(find.text('Basil Plant'), findsOneWidget);
    expect(find.text('3.00'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);

    // Drop the second photo and set a new quantity.
    await tester.tap(find.byIcon(Icons.close).last);
    await tester.pump();
    final quantity = find.byKey(const Key('listing-quantity-field'));
    await tester.ensureVisible(quantity);
    await tester.enterText(quantity, '4');
    await _submit(tester);

    expect(fakeClient.lastUpdatedListingQuantity, 4);
    expect(fakeClient.lastRemovedPhotoIds, [42]);
  });
}
