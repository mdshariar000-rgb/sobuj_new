import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feed_marketplace.dart';
import '../models/listing.dart';
import 'core_providers.dart';
import 'discovery_providers.dart';

/// The marketplace listings mixed into the Home feed. Loaded alongside the
/// posts and refreshed with them (pull to refresh); a failure just leaves
/// the feed as plain posts.
class FeedMarketplaceNotifier
    extends StateNotifier<AsyncValue<FeedMarketplace>> {
  FeedMarketplaceNotifier(this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    final result = await AsyncValue.guard(
      () => _ref.read(apiClientProvider).feedMarketplace(),
    );
    if (mounted) state = result;
  }

  /// Optimistic, rolled back on failure — same as the Marketplace tab's own
  /// save button (NearbyListingsNotifier.toggleSaved()).
  Future<void> toggleSaved(Listing listing) async {
    final wasSaved = listing.isSaved ?? false;
    _replace(listing.copyWith(isSaved: !wasSaved));

    final apiClient = _ref.read(apiClientProvider);
    try {
      final updated = wasSaved
          ? await apiClient.unsaveListing(listing.id)
          : await apiClient.saveListing(listing.id);
      _replace(updated);
      if (_ref.exists(savedListingsProvider)) {
        _ref.invalidate(savedListingsProvider);
      }
    } catch (_) {
      _replace(listing);
      rethrow;
    }
  }

  /// "Not interested" on a carousel card: drops it for the rest of the
  /// session.
  void dismissNearby(Listing listing) {
    final current = state.valueOrNull;
    if (current == null || !mounted) return;
    state = AsyncValue.data(
      current.copyWith(
        nearby: current.nearby.where((item) => item.id != listing.id).toList(),
      ),
    );
  }

  void _replace(Listing listing) {
    final current = state.valueOrNull;
    if (current == null || !mounted) return;
    state = AsyncValue.data(current.replacing(listing));
  }
}

final feedMarketplaceProvider =
    StateNotifierProvider.autoDispose<
      FeedMarketplaceNotifier,
      AsyncValue<FeedMarketplace>
    >((ref) => FeedMarketplaceNotifier(ref));

/// "Hide for now" on the "Fresh near you" carousel — lasts until the app is
/// restarted, so it isn't gone for good.
final nearbyCarouselHiddenProvider = StateProvider<bool>((ref) => false);
