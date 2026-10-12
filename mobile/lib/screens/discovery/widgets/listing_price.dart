import 'package:intl/intl.dart';

import '../../../models/enums.dart';
import '../../../models/listing.dart';

/// Marketplace prices are always pounds — the app is UK-only, so this
/// doesn't follow the device locale (which showed "$" on some phones).
final poundFormat = NumberFormat.simpleCurrency(name: 'GBP');

/// The headline price text for a listing: "£1.55" for anything with a
/// price, otherwise what kind of deal it is ("Swap", "Free", "Wanted").
String listingPriceLabel(Listing listing) {
  final price = listing.price;
  if (listing.transactionType.isRequest) {
    return price != null ? 'Up to ${poundFormat.format(price)}' : 'Wanted';
  }
  if (price != null) return poundFormat.format(price);
  return switch (listing.transactionType) {
    TransactionType.free => 'Free',
    _ => 'Swap',
  };
}
