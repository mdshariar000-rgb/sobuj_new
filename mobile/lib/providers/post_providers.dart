import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comment.dart';
import '../models/post.dart';
import '../models/post_category.dart';
import '../services/api_client.dart';
import 'core_providers.dart';

@immutable
class HomeFeedState {
  const HomeFeedState({
    required this.posts,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<Post> posts;
  final bool hasMore;
  final bool isLoadingMore;

  HomeFeedState copyWith({
    List<Post>? posts,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return HomeFeedState(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// The current Home Feed search term — real, server-side (see
/// HomeFeedController::index()'s `search` handling), not a client-side
/// filter over whatever's already loaded. Changing it re-creates
/// [homeFeedProvider] (autoDispose), which re-fetches from page 1.
final homeFeedSearchProvider = StateProvider<String>((ref) => '');

/// The Home tab's Recent/Disease Alerts/Harvests chip selection — the real
/// admin-managed category *name* (see [postCategoriesProvider]), or null
/// (the "Recent" chip) for every category. Also real, server-side, via
/// HomeFeedController::index()'s `category` handling.
final homeFeedCategoryProvider = StateProvider<String?>((ref) => null);

/// The admin-managed category list — both the Home tab's filter chips and
/// the "new post" composer's category picker read from this single source
/// of truth rather than each guessing at real values independently.
final postCategoriesProvider =
    FutureProvider.autoDispose<List<PostCategory>>((ref) async {
      final apiClient = ref.watch(apiClientProvider);
      return apiClient.postCategories();
    });

/// The general Home Feed: paginated, pull-to-refresh, with create/delete
/// acting optimistically on the already-loaded list rather than refetching.
class HomeFeedNotifier extends StateNotifier<AsyncValue<HomeFeedState>> {
  HomeFeedNotifier(this._apiClient, this._search, this._category)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _apiClient;
  final String _search;
  final String? _category;
  int _page = 1;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _apiClient.homeFeed(
        search: _search.isEmpty ? null : _search,
        category: _category,
        page: 1,
      );
      _page = 1;
      return HomeFeedState(
        posts: response.data,
        hasMore: response.hasMorePages,
        isLoadingMore: false,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final response = await _apiClient.homeFeed(
        search: _search.isEmpty ? null : _search,
        category: _category,
        page: _page + 1,
      );
      _page += 1;
      state = AsyncValue.data(
        current.copyWith(
          posts: [...current.posts, ...response.data],
          hasMore: response.hasMorePages,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      // Best-effort: leave the already-loaded posts in place on failure.
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  /// Throws [ApiException] on failure — the calling screen handles it,
  /// matching AuthController's login()/register() convention.
  Future<void> createPost({
    required String body,
    String? category,
    File? image,
  }) async {
    final post = await _apiClient.createPost(
      body: body,
      category: category,
      image: image,
    );
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(posts: [post, ...current.posts]),
      );
    }
  }

  Future<void> deletePost(int postId) async {
    await _apiClient.deletePost(postId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          posts: current.posts.where((post) => post.id != postId).toList(),
        ),
      );
    }
  }

  /// Toggles optimistically first — the like button should feel instant —
  /// then reconciles with the server's real counts, rolling back on failure.
  Future<void> toggleLike(Post post) async {
    final wasLiked = post.likedByMe ?? false;
    _replacePost(
      post.copyWith(
        likedByMe: !wasLiked,
        likesCount: (post.likesCount ?? 0) + (wasLiked ? -1 : 1),
      ),
    );

    try {
      final updated = wasLiked
          ? await _apiClient.unlikePost(post.id)
          : await _apiClient.likePost(post.id);
      _replacePost(updated);
    } catch (_) {
      _replacePost(post);
      rethrow;
    }
  }

  /// Called after a comment is added/removed elsewhere (the post detail
  /// screen) so the count shown here stays current without a full refetch.
  void updateCommentsCount(int postId, int commentsCount) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        posts: current.posts
            .map(
              (post) => post.id == postId
                  ? post.copyWith(commentsCount: commentsCount)
                  : post,
            )
            .toList(),
      ),
    );
  }

  void _replacePost(Post updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        posts: current.posts
            .map((post) => post.id == updated.id ? updated : post)
            .toList(),
      ),
    );
  }
}

final homeFeedProvider =
    StateNotifierProvider.autoDispose<
      HomeFeedNotifier,
      AsyncValue<HomeFeedState>
    >(
      (ref) => HomeFeedNotifier(
        ref.watch(apiClientProvider),
        ref.watch(homeFeedSearchProvider),
        ref.watch(homeFeedCategoryProvider),
      ),
    );

/// A single post's comment thread, keyed by post id.
class PostCommentsNotifier extends StateNotifier<AsyncValue<List<Comment>>> {
  PostCommentsNotifier(this._apiClient, this._postId)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _apiClient;
  final int _postId;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _apiClient.postComments(_postId);
      return response.data;
    });
  }

  Future<void> addComment(String body, {int? replyToCommentId}) async {
    final comment = await _apiClient.createComment(
      _postId,
      body: body,
      replyToCommentId: replyToCommentId,
    );
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([...current, comment]);
  }

  Future<void> deleteComment(int commentId) async {
    await _apiClient.deleteComment(commentId);
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data(
      current.where((comment) => comment.id != commentId).toList(),
    );
  }
}

final postCommentsProvider = StateNotifierProvider.autoDispose
    .family<PostCommentsNotifier, AsyncValue<List<Comment>>, int>(
      (ref, postId) =>
          PostCommentsNotifier(ref.watch(apiClientProvider), postId),
    );

/// One author's posts — the "My Posts" tab on their profile. Keyed by
/// author id (not hardcoded to "me") so it also works if a public-profile
/// screen ever wants the same tab for someone else.
class AuthorPostsNotifier extends StateNotifier<AsyncValue<List<Post>>> {
  AuthorPostsNotifier(this._apiClient, this._authorId)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _apiClient;
  final int _authorId;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _apiClient.homeFeed(authorId: _authorId);
      return response.data;
    });
  }

  Future<void> toggleLike(Post post) async {
    final wasLiked = post.likedByMe ?? false;
    _replacePost(
      post.copyWith(
        likedByMe: !wasLiked,
        likesCount: (post.likesCount ?? 0) + (wasLiked ? -1 : 1),
      ),
    );

    try {
      final updated = wasLiked
          ? await _apiClient.unlikePost(post.id)
          : await _apiClient.likePost(post.id);
      _replacePost(updated);
    } catch (_) {
      _replacePost(post);
      rethrow;
    }
  }

  void _replacePost(Post updated) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data([
      for (final post in current)
        if (post.id == updated.id) updated else post,
    ]);
  }
}

final authorPostsProvider = StateNotifierProvider.autoDispose
    .family<AuthorPostsNotifier, AsyncValue<List<Post>>, int>(
      (ref, authorId) =>
          AuthorPostsNotifier(ref.watch(apiClientProvider), authorId),
    );
