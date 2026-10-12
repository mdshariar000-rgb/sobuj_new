import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/search_results.dart';
import 'core_providers.dart';
import 'feed_marketplace_providers.dart';

/// Home search results for one term. Running a search also saves it to the
/// user's history, which changes "Picked for you" and the recent searches.
final searchResultsProvider = FutureProvider.autoDispose
    .family<SearchResults, String>((ref, term) async {
      final results = await ref.watch(apiClientProvider).search(term);
      ref.invalidate(searchHistoryProvider);
      ref.invalidate(feedMarketplaceProvider);
      return results;
    });

/// The user's recent searches, newest first — chips under Home's search bar.
final searchHistoryProvider = FutureProvider.autoDispose<List<String>>(
  (ref) => ref.watch(apiClientProvider).searchHistory(),
);
