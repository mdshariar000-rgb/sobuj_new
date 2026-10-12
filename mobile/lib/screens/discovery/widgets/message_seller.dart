import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/listing.dart';
import '../../../providers/core_providers.dart';
import '../../../services/api_exception.dart';
import '../swap_offer_thread_screen.dart';

/// Opens the chat with this listing's seller — creating the deal, or
/// reopening the one already open — like tapping a contact opens a chat.
/// Shared by every listing card's chat button.
Future<void> messageSeller(
  BuildContext context,
  WidgetRef ref,
  Listing listing,
) async {
  try {
    final offer = await ref.read(apiClientProvider).createSwapOffer(listing.id);
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SwapOfferThreadScreen(swapOffer: offer),
        ),
      );
    }
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}
