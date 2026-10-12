import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/enums.dart';
import '../../../models/listing.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/core_providers.dart';
import '../../../providers/discovery_providers.dart';
import '../../../services/api_exception.dart';
import '../../../theme/app_colors.dart';
import '../create_listing_screen.dart';

/// What a seller can do with their own listing — edit it, mark it sold (or
/// put it back on sale), or delete it. Shared by the listing page and the
/// Profile's My Listings. Each returns the listing as it now is, or null if
/// nothing changed (cancelled, failed, or deleted).

Future<Listing?> editOwnListing(BuildContext context, Listing listing) {
  return Navigator.of(context).push<Listing>(
    MaterialPageRoute(builder: (_) => CreateListingScreen(editing: listing)),
  );
}

/// Sold out / no longer available ↔ back on sale. Marking it sold closes
/// any deals still open on it (the server tells those buyers).
Future<Listing?> toggleOwnListingSold(
  BuildContext context,
  WidgetRef ref,
  Listing listing,
) async {
  final markingSold = listing.status != ListingStatus.completed;
  final noun = listing.transactionType == TransactionType.swap
      ? 'swapped'
      : 'sold';
  final confirmed = await _confirm(
    context,
    title: markingSold ? 'Mark as $noun?' : 'Put back on the marketplace?',
    message: markingSold
        ? 'It disappears from the marketplace, and anyone still chatting '
              'about it is told it\'s gone.'
        : 'It will show in the marketplace again.',
    action: markingSold ? 'Mark as $noun' : 'Put back',
  );
  if (!confirmed || !context.mounted) return null;

  return _run(
    context,
    ref,
    () => ref
        .read(apiClientProvider)
        .updateListing(
          listing.id,
          status: markingSold ? ListingStatus.completed : ListingStatus.active,
          // Back on sale with nothing left would be odd — give it one.
          quantity: !markingSold && (listing.quantity ?? 1) < 1 ? 1 : null,
        ),
  );
}

/// Returns true once it's deleted.
Future<bool> deleteOwnListing(
  BuildContext context,
  WidgetRef ref,
  Listing listing,
) async {
  final confirmed = await _confirm(
    context,
    title: 'Delete "${listing.title}"?',
    message:
        'It is removed from the marketplace for good, and anyone still '
        'chatting about it is told it\'s gone.',
    action: 'Delete',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return false;

  try {
    await ref.read(apiClientProvider).deleteListing(listing.id);
    _refreshLists(ref);
    return true;
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
    return false;
  }
}

Future<Listing?> _run(
  BuildContext context,
  WidgetRef ref,
  Future<Listing> Function() call,
) async {
  try {
    final updated = await call();
    _refreshLists(ref);
    return updated;
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
    return null;
  }
}

void _refreshLists(WidgetRef ref) {
  // The profile's "Active Listings" count comes from the signed-in user.
  ref.read(authControllerProvider.notifier).refresh().ignore();
  ref.invalidate(myListingsProvider);
  ref.invalidate(nearbyListingsProvider);
  ref.invalidate(mySwapOffersProvider);
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not now'),
        ),
        TextButton(
          key: const Key('owner-action-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: destructive ? AppColors.error : AppColors.primary,
          ),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// The seller's bar at the bottom of their own listing page.
class ListingOwnerBar extends ConsumerWidget {
  const ListingOwnerBar({
    super.key,
    required this.listing,
    required this.onChanged,
    required this.onDeleted,
  });

  final Listing listing;
  final ValueChanged<Listing> onChanged;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSoldOut = listing.status == ListingStatus.completed;
    final noun = listing.transactionType == TransactionType.swap
        ? 'swapped'
        : 'sold';

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('owner-edit'),
            onPressed: () async {
              final updated = await editOwnListing(context, listing);
              if (updated != null) onChanged(updated);
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: AppColors.textDark,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            key: const Key('owner-toggle-sold'),
            onPressed: () async {
              final updated = await toggleOwnListingSold(context, ref, listing);
              if (updated != null) onChanged(updated);
            },
            icon: Icon(
              isSoldOut ? Icons.replay : Icons.check_circle_outline,
              size: 18,
            ),
            label: Text(isSoldOut ? 'Put back' : 'Mark $noun'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          key: const Key('owner-delete'),
          tooltip: 'Delete listing',
          onPressed: () async {
            if (await deleteOwnListing(context, ref, listing)) onDeleted();
          },
          icon: const Icon(Icons.delete_outline, color: AppColors.error),
        ),
      ],
    );
  }
}
