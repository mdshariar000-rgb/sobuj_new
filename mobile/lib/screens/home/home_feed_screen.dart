import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/post.dart';
import '../../models/post_category.dart';
import '../../providers/auth_providers.dart';
import '../../providers/post_providers.dart';
import '../../providers/shell_providers.dart';
import '../../services/api_exception.dart';
import '../../theme/app_colors.dart';
import '../notifications/notifications_screen.dart';
import '../profile/profile_screen.dart';
import '../shell/widgets/coming_soon_view.dart';
import 'post_detail_screen.dart';
import 'widgets/agri_ai_banner.dart';
import 'widgets/create_post_sheet.dart';
import 'widgets/edit_post_sheet.dart';
import 'widgets/field_diagnostics_card.dart';
import 'widgets/home_hero_header.dart';
import 'widgets/post_card.dart';

/// The Home tab: the general community feed (posts with no group).
class HomeFeedScreen extends ConsumerStatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  ConsumerState<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends ConsumerState<HomeFeedScreen> {
  static const _searchDebounceDuration = Duration(milliseconds: 400);

  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_maybeLoadMore);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _toggleSearch() {
    if (_isSearching) {
      _searchController.clear();
      ref.read(homeFeedSearchProvider.notifier).state = '';
      setState(() => _isSearching = false);
    } else {
      setState(() => _isSearching = true);
      _searchFocusNode.requestFocus();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, () {
      ref.read(homeFeedSearchProvider.notifier).state = value;
    });
  }

  void _maybeLoadMore() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(homeFeedProvider.notifier).loadMore();
    }
  }

  void _openAgriAi() =>
      ref.read(selectedTabIndexProvider.notifier).state = 3;

  Future<void> _toggleLike(Post post) async {
    try {
      await ref.read(homeFeedProvider.notifier).toggleLike(post);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _editPost(Post post) {
    showEditPostSheet(
      context,
      post: post,
      onSubmit: (ref, body, category, image, removeImage) => ref
          .read(homeFeedProvider.notifier)
          .updatePost(
            post.id,
            body: body,
            category: category,
            image: image,
            removeImage: removeImage,
          ),
    );
  }

  Future<void> _deletePost(int postId) async {
    if (!await confirmDeletePost(context) || !mounted) return;
    await ref.read(homeFeedProvider.notifier).deletePost(postId);
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeFeedProvider);
    final selectedCategory = ref.watch(homeFeedCategoryProvider);
    final categoriesAsync = ref.watch(postCategoriesProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final roleLabel = currentUser?.growingSetup?.label != null
        ? '${currentUser!.growingSetup!.label} Grower'
        : currentUser?.experienceLevel?.label != null
        ? '${currentUser!.experienceLevel!.label} Grower'
        : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      floatingActionButton: FloatingActionButton(
        // Explicit, unique per screen: the bottom-nav shell keeps every tab
        // mounted via IndexedStack, so two FABs sharing the default Hero tag
        // at the same time crashes the next Hero transition.
        heroTag: 'home-feed-fab',
        onPressed: () => showCreatePostSheet(context),
        tooltip: 'New post',
        child: const Icon(Icons.camera_alt),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(homeFeedProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(
              child: HomeHeroHeader(
                userName: currentUser?.name ?? 'Grower',
                avatarUrl: currentUser?.avatarUrl,
                roleLabel: roleLabel,
                onAvatarTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ),
                onSearchTap: _toggleSearch,
                onNotificationsTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              ),
            ),
            if (_isSearching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search posts or growers...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: _toggleSearch,
                      ),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: 16, bottom: 16),
                child: FieldDiagnosticsCard(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: AgriAiBanner(
                  onScanOrAsk: _openAgriAi,
                  onChat: _openAgriAi,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Recent Posts (Community Feed)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterChip(
                      label: 'Recent',
                      selected: selectedCategory == null,
                      onTap: () =>
                          ref.read(homeFeedCategoryProvider.notifier).state =
                              null,
                    ),
                    // The rest come from the admin-managed list (see
                    // PostCategoryResource/PostCategoryController on the
                    // backend) — an admin adding or renaming a category
                    // shows up here with no app update needed.
                    for (final category
                        in categoriesAsync.valueOrNull ??
                            const <PostCategory>[]) ...[
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: category.name,
                        selected: selectedCategory == category.name,
                        onTap: () =>
                            ref
                                    .read(homeFeedCategoryProvider.notifier)
                                    .state =
                                category.name,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            feedAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          size: 40,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 12),
                        Text('$error', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () =>
                              ref.read(homeFeedProvider.notifier).refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              data: (feed) {
                if (feed.posts.isEmpty) {
                  final Widget emptyView;
                  if (_isSearching &&
                      ref.watch(homeFeedSearchProvider).isNotEmpty) {
                    emptyView = const ComingSoonView(
                      icon: Icons.search_off,
                      title: 'No matching posts',
                      message: 'Try a different search term.',
                    );
                  } else if (selectedCategory != null) {
                    emptyView = ComingSoonView(
                      icon: Icons.dynamic_feed_outlined,
                      title: 'No ${selectedCategory.toLowerCase()} posts yet',
                      message:
                          'Be the first to share a ${selectedCategory.toLowerCase()} update.',
                    );
                  } else {
                    emptyView = const ComingSoonView(
                      icon: Icons.dynamic_feed_outlined,
                      title: 'Your feed is empty',
                      message: 'Be the first to share what\'s growing.',
                    );
                  }
                  return SliverFillRemaining(child: emptyView);
                }

                return SliverList.builder(
                  itemCount: feed.posts.length + (feed.hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= feed.posts.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final post = feed.posts[index];
                    return PostCard(
                      post: post,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PostDetailScreen(post: post),
                        ),
                      ),
                      onEdit: post.author?.id == currentUser?.id
                          ? () => _editPost(post)
                          : null,
                      onDelete: post.author?.id == currentUser?.id
                          ? () => _deletePost(post.id)
                          : null,
                      onLike: () => _toggleLike(post),
                    );
                  },
                );
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textDark,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: AppColors.surfaceMuted,
      shape: const StadiumBorder(),
      side: BorderSide.none,
    );
  }
}
