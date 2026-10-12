import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/search_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/user_avatar.dart';
import '../discovery/discovery_screen.dart';
import '../discovery/listing_detail_screen.dart';
import '../discovery/seller_profile_screen.dart';
import '../discovery/widgets/message_seller.dart';
import '../groups/group_detail_screen.dart';
import '../shell/widgets/coming_soon_view.dart';
import '../../widgets/shimmer.dart';

/// Results for a search from Home: items, members and groups.
class SearchResultsScreen extends ConsumerWidget {
  const SearchResultsScreen({super.key, required this.term});

  final String term;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authControllerProvider).valueOrNull?.id;
    final resultsAsync = ref.watch(searchResultsProvider(term));
    final textTheme = Theme.of(context).textTheme;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Text(
        text,
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(title: Text('"$term"')),
      body: resultsAsync.when(
        loading: () => const ShimmerListingGrid(rows: 3),
        error: (error, _) => Center(child: Text('$error')),
        data: (results) {
          if (results.isEmpty) {
            return const ComingSoonView(
              icon: Icons.search_off,
              title: 'Nothing found',
              message: 'Try a different item, place or name.',
            );
          }
          return CustomScrollView(
            slivers: [
              if (results.listings.isNotEmpty) ...[
                SliverToBoxAdapter(child: heading('Items')),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: ListingGrid(
                    listings: results.listings,
                    onTap: (listing) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ListingDetailScreen(listing: listing),
                      ),
                    ),
                    onChat: (listing) => listing.owner?.id == currentUserId
                        ? null
                        : () => messageSeller(context, ref, listing),
                    onToggleSave: null,
                  ),
                ),
              ],
              if (results.members.isNotEmpty) ...[
                SliverToBoxAdapter(child: heading('Members')),
                SliverList.builder(
                  itemCount: results.members.length,
                  itemBuilder: (context, index) {
                    final member = results.members[index];
                    return ListTile(
                      key: Key('search-member-${member.id}'),
                      leading: UserAvatar(
                        name: member.name,
                        avatarUrl: member.avatarUrl,
                        radius: 20,
                      ),
                      title: Text(member.name),
                      subtitle: member.locationLabel != null
                          ? Text(member.locationLabel!)
                          : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SellerProfileScreen(userId: member.id),
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (results.groups.isNotEmpty) ...[
                SliverToBoxAdapter(child: heading('Groups')),
                SliverList.builder(
                  itemCount: results.groups.length,
                  itemBuilder: (context, index) {
                    final group = results.groups[index];
                    return ListTile(
                      key: Key('search-group-${group.id}'),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.surfaceMuted,
                        child: Icon(
                          Icons.groups_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      title: Text(group.name),
                      subtitle: group.membersCount != null
                          ? Text(
                              '${group.membersCount} '
                              '${group.membersCount == 1 ? 'member' : 'members'}',
                            )
                          : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GroupDetailScreen(group: group),
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
      ),
    );
  }
}
