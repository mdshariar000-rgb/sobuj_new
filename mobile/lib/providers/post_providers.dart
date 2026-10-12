import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/comment.dart';
import '../models/post.dart';
import '../services/api_client.dart';
import 'core_providers.dart';

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

/// One person's posts — the "My Posts" tab on their profile, and the Posts
/// tab on someone else's. Their posts in groups the viewer can see.
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
      final response = await _apiClient.userPosts(_authorId);
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

  Future<void> deletePost(int postId) async {
    await _apiClient.deletePost(postId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.where((post) => post.id != postId).toList(),
      );
    }
  }

  Future<Post> updatePost(
    int postId, {
    String? body,
    File? image,
    bool removeImage = false,
  }) async {
    final updated = await _apiClient.updatePost(
      postId,
      body: body,
      image: image,
      removeImage: removeImage,
    );
    _replacePost(updated);
    return updated;
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
