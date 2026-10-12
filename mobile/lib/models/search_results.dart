import 'package:flutter/foundation.dart';

import 'app_user.dart';
import 'group.dart';
import 'listing.dart';

/// What Home's search found — see SearchController on the backend.
@immutable
class SearchResults {
  const SearchResults({
    this.listings = const [],
    this.members = const [],
    this.groups = const [],
  });

  final List<Listing> listings;
  final List<AppUser> members;
  final List<Group> groups;

  bool get isEmpty => listings.isEmpty && members.isEmpty && groups.isEmpty;

  factory SearchResults.fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(Object? list, T Function(Map<String, dynamic>) fromJson) =>
        (list as List<dynamic>? ?? const [])
            .map((item) => fromJson(item as Map<String, dynamic>))
            .toList(growable: false);

    return SearchResults(
      listings: parse(json['listings'], Listing.fromJson),
      members: parse(json['members'], AppUser.fromJson),
      groups: parse(json['groups'], Group.fromJson),
    );
  }
}

/// Where a suggested search term came from — mirrors the `type` values of
/// GET /search/suggest.
enum SearchSuggestionType {
  history,
  item,
  place;

  static SearchSuggestionType fromValue(String? value) =>
      SearchSuggestionType.values.firstWhere(
        (type) => type.name == value,
        orElse: () => SearchSuggestionType.item,
      );
}

/// A term to complete the search to.
@immutable
class SearchSuggestion {
  const SearchSuggestion({required this.text, required this.type});

  final String text;
  final SearchSuggestionType type;

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) =>
      SearchSuggestion(
        text: json['text'] as String,
        type: SearchSuggestionType.fromValue(json['type'] as String?),
      );
}

/// Suggestions shown while typing in search — see SearchController::suggest()
/// on the backend. Fetching them doesn't save anything to the history.
@immutable
class SearchSuggestions {
  const SearchSuggestions({
    this.terms = const [],
    this.results = const SearchResults(),
  });

  final List<SearchSuggestion> terms;

  /// The top few items, members and groups to jump straight to.
  final SearchResults results;

  bool get isEmpty => terms.isEmpty && results.isEmpty;

  factory SearchSuggestions.fromJson(Map<String, dynamic> json) =>
      SearchSuggestions(
        terms: (json['terms'] as List<dynamic>? ?? const [])
            .map(
              (item) => SearchSuggestion.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        results: SearchResults.fromJson(json),
      );
}
