import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/search_results.dart';
import '../../providers/core_providers.dart';
import '../../providers/search_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_avatar.dart';
import '../discovery/listing_detail_screen.dart';
import '../discovery/seller_profile_screen.dart';
import '../discovery/widgets/listing_price.dart';
import '../discovery/widgets/listing_thumbnail.dart';
import '../groups/group_detail_screen.dart';
import 'search_results_screen.dart';

/// How long typing must pause before suggestions are fetched.
const _suggestDelay = Duration(milliseconds: 250);

/// Home's full-screen search: recent searches when empty, then live
/// suggestions while typing — terms to complete to, plus the top items,
/// people and groups to jump straight to. Submitting opens
/// SearchResultsScreen.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;

  /// The query the shown suggestions belong to, so a slow response for an
  /// older query never replaces newer ones.
  String _query = '';
  SearchSuggestions? _suggestions;
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final query = value.trim();
    _debounce?.cancel();
    setState(() {
      _query = query;
      if (query.isEmpty) {
        _suggestions = null;
        _loading = false;
      } else {
        _loading = true;
      }
    });
    if (query.isEmpty) return;
    _debounce = Timer(_suggestDelay, () => _fetch(query));
  }

  Future<void> _fetch(String query) async {
    try {
      final suggestions = await ref
          .read(apiClientProvider)
          .searchSuggestions(query);
      if (!mounted || query != _query) return;
      setState(() {
        _suggestions = suggestions;
        _loading = false;
      });
    } on ApiException {
      // Suggestions are a nicety — the user can still submit the search.
      if (mounted && query == _query) setState(() => _loading = false);
    }
  }

  void _search(String value) {
    final term = value.trim();
    if (term.length < 2) return;
    FocusScope.of(context).unfocus();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => SearchResultsScreen(term: term)));
  }

  /// Puts [text] in the search field so the user can keep typing.
  void _fillIn(String text) {
    _controller.value = TextEditingValue(
      text: '$text ',
      selection: TextSelection.collapsed(offset: text.length + 1),
    );
    _onChanged(_controller.text);
  }

  void _open(Widget screen) {
    FocusScope.of(context).unfocus();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          key: const Key('search-screen-field'),
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search items, people, places',
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    key: const Key('search-clear'),
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                  ),
          ),
        ),
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _query.isEmpty ? _buildRecent() : _buildSuggestions(),
    );
  }

  Widget _buildRecent() {
    final terms = ref.watch(searchHistoryProvider).valueOrNull ?? const [];
    if (terms.isEmpty) {
      return const _Hint(
        icon: Icons.search,
        text: 'Find plants, produce, growers, groups and places near you.',
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Recent searches',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                key: const Key('search-clear-history'),
                onPressed: () async {
                  await ref.read(apiClientProvider).clearSearchHistory();
                  ref.invalidate(searchHistoryProvider);
                },
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        for (final term in terms.take(10))
          _TermTile(
            key: Key('search-recent-$term'),
            icon: Icons.history,
            text: term,
            query: '',
            onTap: () => _search(term),
            onFillIn: () => _fillIn(term),
          ),
      ],
    );
  }

  Widget _buildSuggestions() {
    final suggestions = _suggestions;
    final results = suggestions?.results ?? const SearchResults();

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_query.length >= 2)
          _TermTile(
            key: const Key('search-submit-row'),
            icon: Icons.search,
            text: 'Search for "$_query"',
            query: '',
            onTap: () => _search(_query),
          ),
        for (final term in suggestions?.terms ?? const <SearchSuggestion>[])
          _TermTile(
            key: Key('search-suggestion-${term.text}'),
            icon: switch (term.type) {
              SearchSuggestionType.history => Icons.history,
              SearchSuggestionType.place => Icons.place_outlined,
              SearchSuggestionType.item => Icons.search,
            },
            text: term.text,
            query: _query,
            onTap: () => _search(term.text),
            onFillIn: () => _fillIn(term.text),
          ),
        if (results.listings.isNotEmpty) ...[
          const _SectionHeading('Items'),
          for (final listing in results.listings)
            ListTile(
              key: Key('search-suggest-listing-${listing.id}'),
              leading: ListingThumbnail(url: listing.thumbnailUrl, size: 44),
              title: _Highlighted(text: listing.title, query: _query),
              subtitle: Text(
                [
                  listingPriceLabel(listing),
                  if (listing.owner?.locationLabel != null)
                    listing.owner!.locationLabel!,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => _open(ListingDetailScreen(listing: listing)),
            ),
        ],
        if (results.members.isNotEmpty) ...[
          const _SectionHeading('People'),
          for (final member in results.members)
            ListTile(
              key: Key('search-suggest-member-${member.id}'),
              leading: UserAvatar(
                name: member.name,
                avatarUrl: member.avatarUrl,
                radius: 22,
              ),
              title: _Highlighted(text: member.name, query: _query),
              subtitle: member.locationLabel != null
                  ? Text(
                      member.locationLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              onTap: () => _open(SellerProfileScreen(userId: member.id)),
            ),
        ],
        if (results.groups.isNotEmpty) ...[
          const _SectionHeading('Groups'),
          for (final group in results.groups)
            ListTile(
              key: Key('search-suggest-group-${group.id}'),
              leading: const CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.surfaceMuted,
                child: Icon(Icons.groups_outlined, color: AppColors.primary),
              ),
              title: _Highlighted(text: group.name, query: _query),
              subtitle: group.membersCount != null
                  ? Text(
                      '${group.membersCount} '
                      '${group.membersCount == 1 ? 'member' : 'members'}',
                    )
                  : null,
              onTap: () => _open(GroupDetailScreen(group: group)),
            ),
        ],
        if (suggestions != null && suggestions.isEmpty && !_loading)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              _query.length >= 2
                  ? 'No quick matches — search to see everything.'
                  : 'Keep typing…',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// A search term row: tap to search it, ↖ to put it in the field.
class _TermTile extends StatelessWidget {
  const _TermTile({
    super.key,
    required this.icon,
    required this.text,
    required this.query,
    required this.onTap,
    this.onFillIn,
  });

  final IconData icon;
  final String text;
  final String query;
  final VoidCallback onTap;
  final VoidCallback? onFillIn;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: AppColors.textMuted),
      title: _Highlighted(text: text, query: query),
      trailing: onFillIn == null
          ? null
          : IconButton(
              tooltip: 'Edit search',
              icon: const Icon(Icons.north_west, size: 18),
              color: AppColors.textMuted,
              onPressed: onFillIn,
            ),
      onTap: onTap,
    );
  }
}

/// [text] with the part matching [query] in bold.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.query});

  final String text;
  final String query;

  @override
  Widget build(BuildContext context) {
    final start = query.isEmpty
        ? -1
        : text.toLowerCase().indexOf(query.toLowerCase());
    if (start < 0) {
      return Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final end = start + query.length;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text.substring(0, start)),
          TextSpan(
            text: text.substring(start, end),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: text.substring(end)),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
