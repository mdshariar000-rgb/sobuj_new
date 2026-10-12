import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group.dart';
import '../models/group_category.dart';
import '../models/group_join_request.dart';
import '../models/group_member.dart';
import '../models/group_message.dart';
import '../models/message_reaction.dart';
import '../models/message_reply.dart';
import '../models/post.dart';
import '../services/api_client.dart';
import '../services/group_realtime_channel.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

/// The admin-managed category list — both the Groups tab's filter chips and
/// the "Create a Group" screen's category picker read from this single
/// source of truth rather than each guessing at real values independently.
final groupCategoriesProvider = FutureProvider.autoDispose<List<GroupCategory>>(
  (ref) async {
    final apiClient = ref.watch(apiClientProvider);
    final categories = await apiClient.groupCategories();
    // Admin-managed and rarely changes — keep it for the session once loaded,
    // so the chips don't flash a spinner every time a screen opens. (A failed
    // load isn't kept, so it retries next time.)
    ref.keepAlive();
    return categories;
  },
);

@immutable
class GroupsFilters {
  const GroupsFilters({this.search = '', this.category});

  final String search;

  /// null means "All categories" — real server-side filtering on the
  /// `groups.category` column (see GroupController::index()), not a client
  /// side approximation.
  final String? category;

  GroupsFilters copyWith({
    String? search,
    String? category,
    bool clearCategory = false,
  }) {
    return GroupsFilters(
      search: search ?? this.search,
      category: clearCategory ? null : (category ?? this.category),
    );
  }
}

class GroupsFiltersNotifier extends StateNotifier<GroupsFilters> {
  GroupsFiltersNotifier() : super(const GroupsFilters());

  void setSearch(String search) => state = state.copyWith(search: search);

  void setCategory(String? category) {
    state = category == null
        ? state.copyWith(clearCategory: true)
        : state.copyWith(category: category);
  }
}

final groupsFiltersProvider =
    StateNotifierProvider<GroupsFiltersNotifier, GroupsFilters>(
      (ref) => GroupsFiltersNotifier(),
    );

@immutable
class GroupsListState {
  const GroupsListState({
    required this.groups,
    required this.hasMore,
    required this.isLoadingMore,
    required this.total,
  });

  final List<Group> groups;
  final bool hasMore;
  final bool isLoadingMore;

  /// Real total from the paginator's meta — not a fabricated "active" count.
  final int total;

  GroupsListState copyWith({
    List<Group>? groups,
    bool? hasMore,
    bool? isLoadingMore,
    int? total,
  }) {
    return GroupsListState(
      groups: groups ?? this.groups,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      total: total ?? this.total,
    );
  }
}

/// Re-created (and so re-fetched) whenever [groupsFiltersProvider] changes —
/// same dependency-driven refetch as Discovery's nearbyListingsProvider, just
/// wrapped in a StateNotifier so join/leave can mutate the loaded list.
class GroupsListNotifier extends StateNotifier<AsyncValue<GroupsListState>> {
  GroupsListNotifier(this._apiClient, this._filters, {this.tab})
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _apiClient;
  final GroupsFilters _filters;

  /// Which Groups tab this list is for — null for every group (used by
  /// screens outside the Groups tab, e.g. picking a group for an event).
  final GroupsTab? tab;
  int _page = 1;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _apiClient.groups(
        search: _filters.search,
        category: _filters.category,
        membership: tab?.membership,
        page: 1,
      );
      _page = 1;
      return GroupsListState(
        groups: response.data,
        hasMore: response.hasMorePages,
        isLoadingMore: false,
        total: response.total,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final response = await _apiClient.groups(
        search: _filters.search,
        category: _filters.category,
        membership: tab?.membership,
        page: _page + 1,
      );
      _page += 1;
      state = AsyncValue.data(
        current.copyWith(
          groups: [...current.groups, ...response.data],
          hasMore: response.hasMorePages,
          isLoadingMore: false,
          total: response.total,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> createGroup({
    required String name,
    required String slug,
    String? description,
    String? category,
    bool isPrivate = false,
    File? coverImage,
    File? avatar,
  }) async {
    final group = await _apiClient.createGroup(
      name: name,
      slug: slug,
      description: description,
      category: category,
      isPrivate: isPrivate,
      coverImage: coverImage,
      avatar: avatar,
    );
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          groups: [group.copyWith(isMember: true), ...current.groups],
          total: current.total + 1,
        ),
      );
    }
  }

  /// A public group joins instantly. A private group only files a request
  /// — see [JoinGroupResult] — so the card flips to a disabled "Request
  /// Pending" state instead of "Joined".
  /// Returns true once a member — false when it's a private group and a
  /// join request was sent instead.
  Future<bool> joinGroup(int groupId) async {
    final result = await _apiClient.joinGroup(groupId);
    result.when(
      joined: (_) => _updateGroup(groupId, (group) {
        return group.copyWith(
          isMember: true,
          membersCount: (group.membersCount ?? 0) + 1,
        );
      }),
      requested: () => _updateGroup(
        groupId,
        (group) => group.copyWith(joinRequestPending: true),
      ),
    );
    return state.valueOrNull?.groups
            .where((g) => g.id == groupId)
            .firstOrNull
            ?.isMember ??
        false;
  }

  /// Takes a group out of this list — e.g. one just joined leaves the
  /// Discover tab for My groups.
  void removeGroup(int groupId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(
        groups: current.groups.where((g) => g.id != groupId).toList(),
        total: current.total > 0 ? current.total - 1 : 0,
      ),
    );
  }

  Future<void> leaveGroup(int groupId) async {
    await _apiClient.leaveGroup(groupId);
    _updateGroup(groupId, (group) {
      return group.copyWith(
        isMember: false,
        membersCount: (group.membersCount ?? 1) - 1,
      );
    });
  }

  /// Opening a group's chat marks its messages read on the server (see
  /// GroupMessageController::index()), so its unread badge goes too.
  void markChatRead(int groupId) =>
      _updateGroup(groupId, (group) => group.copyWith(unreadCount: 0));

  void _updateGroup(int groupId, Group Function(Group) update) {
    final current = state.valueOrNull;
    if (current == null) return;

    state = AsyncValue.data(
      current.copyWith(
        groups: current.groups
            .map((group) => group.id == groupId ? update(group) : group)
            .toList(),
      ),
    );
  }
}

/// The Groups screen's two tabs.
enum GroupsTab {
  mine('mine'),
  discover('others');

  const GroupsTab(this.membership);

  /// The API's `membership` filter value.
  final String membership;
}

/// One Groups tab's list: "My groups" or "Discover".
final groupsTabListProvider = StateNotifierProvider.autoDispose
    .family<GroupsListNotifier, AsyncValue<GroupsListState>, GroupsTab>(
      (ref, tab) => GroupsListNotifier(
        ref.watch(apiClientProvider),
        ref.watch(groupsFiltersProvider),
        tab: tab,
      ),
    );

final groupsListProvider =
    StateNotifierProvider.autoDispose<
      GroupsListNotifier,
      AsyncValue<GroupsListState>
    >(
      (ref) => GroupsListNotifier(
        ref.watch(apiClientProvider),
        ref.watch(groupsFiltersProvider),
      ),
    );

/// A single group's own detail (join/leave from the detail screen updates
/// this independently of whatever list the user navigated in from).
class GroupDetailNotifier extends StateNotifier<AsyncValue<Group>> {
  GroupDetailNotifier(this._apiClient, this._groupId, Group? initial)
    : super(
        initial != null ? AsyncValue.data(initial) : const AsyncValue.loading(),
      ) {
    if (initial == null) refresh();
  }

  final ApiClient _apiClient;
  final int _groupId;

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => _apiClient.group(_groupId));
  }

  /// A public group joins instantly. A private group only files a request
  /// — see [JoinGroupResult] — so the button flips to a disabled "Request
  /// Pending" state instead of "Joined".
  Future<void> join() async {
    final result = await _apiClient.joinGroup(_groupId);
    result.when(
      joined: (group) => state = AsyncValue.data(group),
      requested: () {
        final current = state.valueOrNull;
        if (current != null) {
          state = AsyncValue.data(current.copyWith(joinRequestPending: true));
        }
      },
    );
  }

  /// Withdraws the caller's own still-pending request to join a private
  /// group.
  Future<void> cancelJoinRequest() async {
    await _apiClient.cancelJoinRequest(_groupId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(current.copyWith(joinRequestPending: false));
    }
  }

  Future<void> leave() async {
    await _apiClient.leaveGroup(_groupId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          isMember: false,
          membersCount: (current.membersCount ?? 1) - 1,
        ),
      );
    }
  }

  /// Edits the group's own real fields (name/description/category/privacy/
  /// cover/avatar) from the Group Settings screen — the backend re-checks
  /// the real admin/creator authorization on every call, this isn't just a
  /// client-side gate.
  Future<void> updateGroup({
    String? name,
    String? description,
    String? category,
    bool? isPrivate,
    File? coverImage,
    File? avatar,
  }) async {
    final updated = await _apiClient.updateGroup(
      _groupId,
      name: name,
      description: description,
      category: category,
      isPrivate: isPrivate,
      coverImage: coverImage,
      avatar: avatar,
    );
    state = AsyncValue.data(updated);
  }

  /// Pins a new chat announcement (or clears it, with an empty string) — the
  /// backend re-checks the real admin/creator authorization on every call,
  /// this isn't just a client-side gate.
  Future<void> setPinnedMessage(String pinnedMessage) async {
    final updated = await _apiClient.updateGroup(
      _groupId,
      pinnedMessage: pinnedMessage,
    );
    state = AsyncValue.data(updated);
  }
}

final groupDetailProvider = StateNotifierProvider.autoDispose
    .family<GroupDetailNotifier, AsyncValue<Group>, Group>(
      (ref, group) =>
          GroupDetailNotifier(ref.watch(apiClientProvider), group.id, group),
    );

@immutable
class GroupPostsState {
  const GroupPostsState({
    required this.posts,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<Post> posts;
  final bool hasMore;
  final bool isLoadingMore;

  GroupPostsState copyWith({
    List<Post>? posts,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return GroupPostsState(
      posts: posts ?? this.posts,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

/// A single group's discussion-thread posts — the group-scoped counterpart
/// to the other paginated lists.
class GroupPostsNotifier extends StateNotifier<AsyncValue<GroupPostsState>> {
  GroupPostsNotifier(this._apiClient, this._groupId)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _apiClient;
  final int _groupId;
  int _page = 1;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _apiClient.groupPosts(_groupId, page: 1);
      _page = 1;
      return GroupPostsState(
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
      final response = await _apiClient.groupPosts(_groupId, page: _page + 1);
      _page += 1;
      state = AsyncValue.data(
        current.copyWith(
          posts: [...current.posts, ...response.data],
          hasMore: response.hasMorePages,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }

  Future<void> createPost({required String body, File? image}) async {
    final post = await _apiClient.createPost(
      body: body,
      groupId: _groupId,
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

  /// A group admin approves a pending (or previously rejected) post,
  /// flipping it visible to the rest of the group in place.
  Future<void> approvePost(int postId) async {
    await _apiClient.approvePost(postId);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.copyWith(
          posts: current.posts
              .map(
                (post) => post.id == postId
                    ? post.copyWith(approvalStatus: 'approved')
                    : post,
              )
              .toList(),
        ),
      );
    }
  }

  /// A group admin rejects a pending post — it's removed from this admin's
  /// own view immediately, same as deletePost().
  Future<void> rejectPost(int postId) async {
    await _apiClient.rejectPost(postId);
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

final groupPostsProvider = StateNotifierProvider.autoDispose
    .family<GroupPostsNotifier, AsyncValue<GroupPostsState>, int>(
      (ref, groupId) =>
          GroupPostsNotifier(ref.watch(apiClientProvider), groupId),
    );

/// A group's real member roster — the "Members" tab on the group detail
/// screen. autoDispose since it's a moderate-sized list only needed while
/// that tab is visible.
final groupMembersProvider = FutureProvider.autoDispose
    .family<List<GroupMember>, int>((ref, groupId) async {
      final apiClient = ref.watch(apiClientProvider);
      final response = await apiClient.groupMembers(groupId);
      return response.data;
    });

/// A group admin's real pending join requests — approve/reject shrink this
/// list locally rather than a full refetch, same pattern as
/// GroupPostsNotifier.deletePost().
class GroupJoinRequestsNotifier
    extends StateNotifier<AsyncValue<List<GroupJoinRequest>>> {
  GroupJoinRequestsNotifier(this._apiClient, this._groupId)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _apiClient;
  final int _groupId;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _apiClient.groupJoinRequests(_groupId);
      return response.data;
    });
  }

  Future<void> approve(int joinRequestId) async {
    await _apiClient.decideJoinRequest(_groupId, joinRequestId, approve: true);
    _remove(joinRequestId);
  }

  Future<void> reject(int joinRequestId) async {
    await _apiClient.decideJoinRequest(_groupId, joinRequestId, approve: false);
    _remove(joinRequestId);
  }

  void _remove(int joinRequestId) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.where((request) => request.id != joinRequestId).toList(),
    );
  }
}

final groupJoinRequestsProvider = StateNotifierProvider.autoDispose
    .family<GroupJoinRequestsNotifier, AsyncValue<List<GroupJoinRequest>>, int>(
      (ref, groupId) =>
          GroupJoinRequestsNotifier(ref.watch(apiClientProvider), groupId),
    );

/// A single group's real-time chat thread — the counterpart to
/// SwapOfferMessagesNotifier, just scoped to a group instead of a swap offer.
class GroupMessagesNotifier
    extends StateNotifier<AsyncValue<List<GroupMessage>>> {
  GroupMessagesNotifier(this._apiClient, this._groupId, this._ref)
    : super(const AsyncValue.loading()) {
    refresh();
  }

  final ApiClient _apiClient;
  final int _groupId;
  final Ref _ref;
  int _nextTempId = -1;

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await _apiClient.groupMessages(_groupId);
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
    final optimistic = GroupMessage(
      id: tempId,
      groupId: _groupId,
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
      final message = await _apiClient.sendGroupMessage(
        _groupId,
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
      final reactions = await _apiClient.setGroupMessageReaction(
        _groupId,
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
  /// with its own broadcast echo (toOthers() usually prevents this, but the
  /// dedup is cheap insurance).
  /// A realtime push. The server can echo the user's own message back
  /// before their send request returns — it then takes the place of the
  /// matching "Sending…" bubble, so the message never shows twice.
  void receiveMessage(GroupMessage message) {
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

  void _append(GroupMessage message) {
    final current = state.valueOrNull ?? [];
    if (current.any((m) => m.id == message.id)) return;
    state = AsyncValue.data([...current, message]);
  }

  /// Swaps the pending placeholder for the server-confirmed message — unless
  /// the realtime echo already delivered it first (a real race: Reverb's
  /// push can beat this very request's own HTTP response), in which case
  /// the placeholder is just dropped so the message isn't shown twice.
  void _replace(int tempId, GroupMessage message) {
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

final groupMessagesProvider = StateNotifierProvider.autoDispose
    .family<GroupMessagesNotifier, AsyncValue<List<GroupMessage>>, int>((
      ref,
      groupId,
    ) {
      return GroupMessagesNotifier(ref.watch(apiClientProvider), groupId, ref);
    });

/// Builds (but doesn't connect) the live-chat WebSocket for one group. A
/// plain (non-autoDispose) family provider so the chat screen controls its
/// connect/dispose lifecycle explicitly — mirrors
/// swapOfferRealtimeChannelProvider.
final groupRealtimeChannelProvider = Provider.family<GroupRealtimeChannel, int>(
  (ref, groupId) {
    return GroupRealtimeChannel(dio: ref.watch(dioProvider), groupId: groupId);
  },
);
