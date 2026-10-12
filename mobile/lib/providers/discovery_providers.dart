import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:io';

import '../config/app_config.dart';
import '../models/app_user.dart';
import '../models/enums.dart';
import '../models/listing.dart';
import '../models/listing_category.dart';
import '../models/listing_review.dart';
import '../models/message_reaction.dart';
import '../models/message_reply.dart';
import '../models/swap_message.dart';
import '../models/swap_offer.dart';
import '../services/api_client.dart';
import '../services/swap_offer_realtime_channel.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'feed_marketplace_providers.dart';
import 'location_providers.dart';

enum DiscoveryViewMode { list, map }

/// The admin-managed marketplace category list — powers both the Discovery
/// filter chips and the "Create a Listing" category picker.
final listingCategoriesProvider =
    FutureProvider.autoDispose<List<ListingCategory>>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      return apiClient.listingCategories();
    });

/// Real (server-side, via `sort=`), not a client-side re-order — see
/// DiscoveryController::nearby().
enum DiscoverySort {
  nearest('nearest', 'Nearest'),
  newest('newest', 'Newest');

  const DiscoverySort(this.value, this.label);

  final String value;
  final String label;
}

@immutable
class DiscoveryFilters {
  const DiscoveryFilters({
    this.searchTerm = '',
    this.category,
    this.transactionType,
    this.radiusKm = AppConfig.defaultRadiusKm,
    this.sort = DiscoverySort.newest,
  });

  final String searchTerm;
  final String? category;
  final TransactionType? transactionType;
  final double radiusKm;
  final DiscoverySort sort;

  DiscoveryFilters copyWith({
    String? searchTerm,
    String? category,
    bool clearCategory = false,
    TransactionType? transactionType,
    bool clearTransactionType = false,
    double? radiusKm,
    DiscoverySort? sort,
  }) {
    return DiscoveryFilters(
      searchTerm: searchTerm ?? this.searchTerm,
      category: clearCategory ? null : (category ?? this.category),
      transactionType: clearTransactionType
          ? null
          : (transactionType ?? this.transactionType),
      radiusKm: radiusKm ?? this.radiusKm,
      sort: sort ?? this.sort,
    );
  }
}

class DiscoveryFiltersNotifier extends StateNotifier<DiscoveryFilters> {
  DiscoveryFiltersNotifier() : super(const DiscoveryFilters());

  void setSearchTerm(String term) => state = state.copyWith(searchTerm: term);

  /// Tapping the already-selected category chip clears it (toggle behavior).
  void toggleCategory(String category) {
    state = state.category == category
        ? state.copyWith(clearCategory: true)
        : state.copyWith(category: category);
  }

  void toggleTransactionType(TransactionType type) {
    state = state.transactionType == type
        ? state.copyWith(clearTransactionType: true)
        : state.copyWith(transactionType: type);
  }

  /// Sets (or, with null, clears) the transaction type directly — for a
  /// fixed tab row ("All" / "For Sale" / ...) rather than a toggleable chip.
  void selectTransactionType(TransactionType? type) {
    state = type == null
        ? state.copyWith(clearTransactionType: true)
        : state.copyWith(transactionType: type);
  }

  void setRadiusKm(double radiusKm) =>
      state = state.copyWith(radiusKm: radiusKm);

  void setSort(DiscoverySort sort) => state = state.copyWith(sort: sort);

  /// Applies a whole set of filters at once — the Filters sheet edits a
  /// draft copy and only commits it on "Apply Filters".
  void apply(DiscoveryFilters filters) => state = filters;
}

final discoveryFiltersProvider =
    StateNotifierProvider<DiscoveryFiltersNotifier, DiscoveryFilters>((ref) {
      return DiscoveryFiltersNotifier();
    });

final viewModeProvider = StateProvider<DiscoveryViewMode>(
  (ref) => DiscoveryViewMode.list,
);

/// The listing whose map pin was last tapped, shown in the preview card. Null
/// means no pin is selected (or we're in list view).
final selectedListingIdProvider = StateProvider<int?>((ref) => null);

/// Re-fetches whenever filters or the account location change. autoDispose so
/// the (potentially large) result list isn't kept around once the Discovery
/// screen is popped.
class NearbyListingsNotifier extends StateNotifier<AsyncValue<List<Listing>>> {
  NearbyListingsNotifier(this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final filters = _ref.read(discoveryFiltersProvider);
      final position = await _ref.read(accountLocationProvider.future);
      final apiClient = _ref.read(apiClientProvider);

      final response = await apiClient.nearbyListings(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: filters.radiusKm,
        category: filters.category,
        transactionType: filters.transactionType,
        search: filters.searchTerm,
        sort: filters.sort.value,
      );

      return response.data;
    });
  }

  /// Toggles optimistically, then reconciles with the server; rolls back on
  /// failure. Real save/unsave — see ListingController::save()/unsave().
  Future<void> toggleSaved(Listing listing) async {
    final wasSaved = listing.isSaved ?? false;
    _replaceListing(listing.copyWith(isSaved: !wasSaved));

    final apiClient = _ref.read(apiClientProvider);
    try {
      final updated = wasSaved
          ? await apiClient.unsaveListing(listing.id)
          : await apiClient.saveListing(listing.id);
      _replaceListing(updated);
    } catch (_) {
      _replaceListing(listing);
      rethrow;
    }
  }

  void _replaceListing(Listing updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data([
      for (final listing in current)
        if (listing.id == updated.id) updated else listing,
    ]);
  }
}

final nearbyListingsProvider =
    StateNotifierProvider.autoDispose<
      NearbyListingsNotifier,
      AsyncValue<List<Listing>>
    >((ref) {
      // Re-created (and so re-fetched) whenever filters change — same
      // dependency-driven refetch as GroupsListNotifier.
      ref.watch(discoveryFiltersProvider);
      return NearbyListingsNotifier(ref);
    });

/// The "Favorites" list — every listing the user has tapped the heart icon
/// on. autoDispose so it's re-fetched fresh each time the screen opens
/// (cheap: a personal list, not the full nearby-search result set).
class SavedListingsNotifier extends StateNotifier<AsyncValue<List<Listing>>> {
  SavedListingsNotifier(this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.savedListings();
      return response.data;
    });
  }

  /// Unsaving here removes the listing from this list entirely — this view
  /// is specifically "things I've saved", so an unsaved item doesn't belong
  /// in it anymore. Optimistic, with rollback on failure.
  Future<void> unsave(Listing listing) async {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(current.where((l) => l.id != listing.id).toList());

    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.unsaveListing(listing.id);
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }
}

final savedListingsProvider =
    StateNotifierProvider.autoDispose<
      SavedListingsNotifier,
      AsyncValue<List<Listing>>
    >((ref) => SavedListingsNotifier(ref));

/// The signed-in user's own listings (any status) — the "My Listings" tab
/// on their profile.
class MyListingsNotifier extends StateNotifier<AsyncValue<List<Listing>>> {
  MyListingsNotifier(this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final apiClient = _ref.read(apiClientProvider);
      final response = await apiClient.myListings();
      return response.data;
    });
  }
}

final myListingsProvider =
    StateNotifierProvider.autoDispose<
      MyListingsNotifier,
      AsyncValue<List<Listing>>
    >((ref) => MyListingsNotifier(ref));

/// Offers involving the current user (as requester or as the listing
/// owner) — the Messages inbox reached from the Marketplace header.
final mySwapOffersProvider = FutureProvider.autoDispose<List<SwapOffer>>((
  ref,
) async {
  final apiClient = ref.watch(apiClientProvider);
  final response = await apiClient.mySwapOffers();
  return response.data;
});

/// A single swap offer's message thread.
class SwapOfferMessagesNotifier
    extends StateNotifier<AsyncValue<List<SwapMessage>>> {
  SwapOfferMessagesNotifier(this._apiClient, this._swapOfferId, this._ref)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _apiClient;
  final int _swapOfferId;
  final Ref _ref;
  int _nextTempId = -1;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _apiClient.swapOfferMessages(_swapOfferId);
      return response.data;
    });
  }

  /// Shows the message immediately as a pending bubble (the network round
  /// trip otherwise made it feel like the app had swallowed the tap), then
  /// swaps it for the server-confirmed message once the request resolves —
  /// or removes it and rethrows on failure, letting the screen's existing
  /// error handling show what went wrong.
  Future<void> sendMessage({
    String? body,
    List<File> images = const [],
    MessageReply? replyTo,
  }) async {
    final me = _ref.read(authControllerProvider).valueOrNull;
    final tempId = _nextTempId--;
    final optimistic = SwapMessage(
      id: tempId,
      swapOfferId: _swapOfferId,
      isSystemEvent: false,
      body: body,
      sender: me,
      createdAt: DateTime.now(),
      isPending: true,
      localImages: images,
      replyToId: replyTo?.id,
      replyTo: replyTo,
    );
    _append(optimistic);

    try {
      final message = await _apiClient.sendSwapOfferMessage(
        _swapOfferId,
        body: body,
        images: images,
        replyToId: replyTo?.id,
      );
      _replace(tempId, message);
    } catch (_) {
      _remove(tempId);
      rethrow;
    }
  }

  /// Sets or clears the signed-in user's reaction to [emoji] (tapping
  /// their current one removes it): updates the bubble straight away, then
  /// settles on the server's answer — or rolls back and rethrows.
  Future<void> react(int messageId, String emoji) async {
    final me = _ref.read(authControllerProvider).valueOrNull?.id;
    final message = state.valueOrNull
        ?.where((m) => m.id == messageId)
        .firstOrNull;
    if (me == null || message == null || message.isPending) return;

    final before = message.reactions;
    final removing = myReaction(before, me) == emoji;
    applyReactions(messageId, toggleReaction(before, userId: me, emoji: emoji));
    try {
      final reactions = await _apiClient.setSwapOfferMessageReaction(
        _swapOfferId,
        messageId,
        removing ? null : emoji,
      );
      applyReactions(messageId, reactions);
    } catch (_) {
      applyReactions(messageId, before);
      rethrow;
    }
  }

  /// Replaces one message's reactions — also how a realtime
  /// `message.reacted` update from someone else lands.
  void applyReactions(int messageId, List<MessageReaction> reactions) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data([
      for (final m in current)
        if (m.id == messageId) m.withReactions(reactions) else m,
    ]);
  }

  /// Adds a message that arrived over the realtime channel — de-duplicated
  /// by id, since the sender's own optimistic [sendMessage] add can race
  /// with its own broadcast echo.
  /// A realtime push. The server can echo the user's own message back
  /// before their send request returns — it then takes the place of the
  /// matching "Sending…" bubble, so the message never shows twice.
  void receiveMessage(SwapMessage message) {
    final current = state.valueOrNull ?? [];
    final me = _ref.read(authControllerProvider).valueOrNull?.id;
    final pendingIndex = message.sender?.id == me
        ? current.indexWhere(
            (m) =>
                m.isPending &&
                m.body == message.body &&
                m.localImages.length == message.imageUrls.length,
          )
        : -1;
    if (pendingIndex < 0 || current.any((m) => m.id == message.id)) {
      _append(message);
      return;
    }
    state = AsyncValue.data([...current]..[pendingIndex] = message);
  }

  void _append(SwapMessage message) {
    final current = state.valueOrNull ?? [];
    if (current.any((m) => m.id == message.id)) return;
    state = AsyncValue.data([...current, message]);
  }

  /// Swaps the pending placeholder for the server-confirmed message — unless
  /// the realtime echo already delivered it first (a real race: Reverb's
  /// push can beat this very request's own HTTP response), in which case
  /// the placeholder is just dropped so the message isn't shown twice.
  void _replace(int tempId, SwapMessage message) {
    final current = state.valueOrNull ?? [];
    final alreadyDelivered = current.any((m) => m.id == message.id);
    state = AsyncValue.data([
      for (final m in current)
        if (m.id != tempId) m else if (!alreadyDelivered) message,
    ]);
  }

  void _remove(int tempId) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(current.where((m) => m.id != tempId).toList());
  }
}

final swapOfferMessagesProvider = StateNotifierProvider.autoDispose
    .family<SwapOfferMessagesNotifier, AsyncValue<List<SwapMessage>>, int>((
      ref,
      swapOfferId,
    ) {
      return SwapOfferMessagesNotifier(
        ref.watch(apiClientProvider),
        swapOfferId,
        ref,
      );
    });

/// Builds (but doesn't connect) the live-chat WebSocket for one swap offer
/// thread. A plain (non-autoDispose) family provider so the thread screen
/// controls its connect/dispose lifecycle explicitly — and so tests can
/// override it with a no-op fake instead of opening a real socket to
/// production.
final swapOfferRealtimeChannelProvider =
    Provider.family<SwapOfferRealtimeChannel, int>((ref, swapOfferId) {
      return SwapOfferRealtimeChannel(
        dio: ref.watch(dioProvider),
        swapOfferId: swapOfferId,
      );
    });

/// A grower's public profile — "View Seller Profile" on a listing detail (or
/// anywhere else `openUserProfile` is used). A StateNotifier rather than a
/// plain FutureProvider so the Follow button can toggle optimistically, same
/// pattern as NearbyListingsNotifier.toggleSaved().
class UserProfileNotifier extends StateNotifier<AsyncValue<AppUser>> {
  UserProfileNotifier(this._ref, this._userId)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref _ref;
  final int _userId;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final apiClient = _ref.read(apiClientProvider);
      return apiClient.userProfile(_userId);
    });
  }

  /// Toggles optimistically, then reconciles with the server's fresh counts;
  /// rolls back on failure. Real follow/unfollow — see FollowController.
  Future<void> toggleFollow() async {
    final current = state.valueOrNull;
    if (current == null) return;

    final wasFollowing = current.isFollowing ?? false;
    state = AsyncValue.data(
      current.copyWith(
        isFollowing: !wasFollowing,
        followersCount: (current.followersCount ?? 0) + (wasFollowing ? -1 : 1),
      ),
    );

    final apiClient = _ref.read(apiClientProvider);
    try {
      final updated = wasFollowing
          ? await apiClient.unfollowUser(_userId)
          : await apiClient.followUser(_userId);
      // Only the follow fields: the follow response leaves out the profile's
      // other counts and trust signals, which haven't changed.
      state = AsyncValue.data(
        current.copyWith(
          isFollowing: updated.isFollowing,
          followersCount: updated.followersCount,
          followingCount: updated.followingCount,
        ),
      );
      // Home's "Picked for you" includes new listings from followed
      // growers — refetch it so this shows up without a pull-to-refresh.
      if (_ref.exists(feedMarketplaceProvider)) {
        _ref.invalidate(feedMarketplaceProvider);
      }
    } catch (_) {
      state = AsyncValue.data(current);
      rethrow;
    }
  }
}

final userProfileProvider = StateNotifierProvider.autoDispose
    .family<UserProfileNotifier, AsyncValue<AppUser>, int>((ref, userId) {
      return UserProfileNotifier(ref, userId);
    });

/// That grower's active listings, shown below their profile.
final userListingsProvider = FutureProvider.autoDispose
    .family<List<Listing>, int>((ref, userId) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.userListings(userId);
      return response.data;
    });

/// A single listing's reviews (star rating + comment), keyed by listing id
/// — same shape as PostCommentsNotifier (first page only, no infinite
/// scroll; review lists are short).
class ListingReviewsNotifier
    extends StateNotifier<AsyncValue<List<ListingReview>>> {
  ListingReviewsNotifier(this._apiClient, this._listingId)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _apiClient;
  final int _listingId;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _apiClient.listingReviews(_listingId);
      return response.data;
    });
  }

  /// Idempotent upsert — matches ListingReviewController::store() on the
  /// backend: submitting again replaces the caller's existing review in
  /// this list rather than adding a second one.
  Future<void> submitReview({required int rating, String? comment}) async {
    final review = await _apiClient.submitListingReview(
      _listingId,
      rating: rating,
      comment: comment,
    );
    final current = state.valueOrNull ?? [];
    final existingIndex = current.indexWhere(
      (r) => r.reviewer?.id != null && r.reviewer?.id == review.reviewer?.id,
    );
    state = AsyncValue.data(
      existingIndex == -1
          ? [review, ...current]
          : [
              for (var i = 0; i < current.length; i++)
                i == existingIndex ? review : current[i],
            ],
    );
  }

  Future<void> deleteReview(int reviewId) async {
    await _apiClient.deleteListingReview(_listingId, reviewId);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.where((review) => review.id != reviewId).toList(),
    );
  }
}

final listingReviewsProvider = StateNotifierProvider.autoDispose
    .family<ListingReviewsNotifier, AsyncValue<List<ListingReview>>, int>(
      (ref, listingId) =>
          ListingReviewsNotifier(ref.watch(apiClientProvider), listingId),
    );

/// That grower's followers / who they follow — the "Followers" and
/// "Following" counts on their profile, each opening a simple list screen.
final userFollowersProvider = FutureProvider.autoDispose
    .family<List<AppUser>, int>((ref, userId) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.userFollowers(userId);
      return response.data;
    });

final userFollowingProvider = FutureProvider.autoDispose
    .family<List<AppUser>, int>((ref, userId) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.userFollowing(userId);
      return response.data;
    });
