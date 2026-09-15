import 'package:flutter/foundation.dart';

import 'app_user.dart';

/// The group chat's real most-recent message — mirrors SwapOfferLastMessage,
/// just without an isSystemEvent flag (group chat has no system events).
@immutable
class GroupLastMessage {
  const GroupLastMessage({
    this.body,
    required this.hasImage,
    this.senderId,
    this.senderName,
    required this.createdAt,
  });

  final String? body;
  final bool hasImage;
  final int? senderId;
  final String? senderName;
  final DateTime createdAt;

  factory GroupLastMessage.fromJson(Map<String, dynamic> json) {
    return GroupLastMessage(
      body: json['body'] as String?,
      hasImage: json['has_image'] as bool,
      senderId: json['sender_id'] as int?,
      senderName: json['sender_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Mirrors GroupResource on the backend.
@immutable
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.category,
    this.visibility = 'public',
    this.isVerified,
    this.coverImageUrl,
    this.avatarUrl,
    this.membersCount,
    this.postsCount,
    this.postsTodayCount,
    this.creator,
    this.isMember,
    this.myRole,
    this.joinRequestPending,
    this.pendingJoinRequestsCount,
    this.pinnedMessage,
    this.pinnedBy,
    this.pinnedAt,
    this.unreadCount,
    this.lastMessage,
    required this.createdAt,
  });

  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? category;

  /// 'public' or 'private' — see GroupResource::visibility on the backend.
  /// Defaults to 'public' so every existing call site that doesn't pass it
  /// (tests, older cached data) keeps behaving as it always has.
  final String visibility;

  /// True once a site admin has verified this group from the web admin
  /// panel — see GroupResource::verified on the backend (`verified_at !==
  /// null`). Renders the same green checkmark treatment already used for
  /// AppUser.isVerified.
  final bool? isVerified;
  final String? coverImageUrl;

  /// A real, optional small emblem/logo distinct from the wide cover photo
  /// — see GroupResource::avatar_url on the backend.
  final String? avatarUrl;
  final int? membersCount;

  /// Real total discussion-post count — the "All Posts" tab label. Only
  /// present on the detail endpoint (not the list), same convention as
  /// postsTodayCount.
  final int? postsCount;

  /// Real count of this group's discussion posts created today — see
  /// GroupResource::posts_today_count on the backend. Only present where the
  /// backend attaches it (currently the groups list and a single group's
  /// detail), same nullable-until-eager-loaded convention as membersCount.
  final int? postsTodayCount;
  final AppUser? creator;

  /// Only present when the request was authenticated — see
  /// GroupResource::is_member on the backend.
  final bool? isMember;

  /// The current user's real group_members.role — 'admin' or 'member' — only
  /// present where the backend eager-loads the full members relation (show/
  /// store/join/leave, not the plain list). Used to gate admin-only UI (e.g.
  /// pinning a chat message) — never shown as a badge for "Agronomist"-style
  /// invented professional titles.
  final String? myRole;

  /// True only when *this* user has a real pending request to join this
  /// (private) group — see GroupResource::join_request_pending. Drives the
  /// "Request to Join" → "Request Pending" button state.
  final bool? joinRequestPending;

  /// Only meaningful to this group's admin — how many real requests are
  /// awaiting their decision — see GroupResource::pending_join_requests_count.
  final int? pendingJoinRequestsCount;

  /// A real admin-set announcement shown atop the group chat — see
  /// GroupController::update()'s pinned_message handling. Null when nothing
  /// is pinned.
  final String? pinnedMessage;
  final AppUser? pinnedBy;
  final DateTime? pinnedAt;

  /// Real unread chat-message count for this user in this group — see
  /// GroupResource::unread_count. Zero for a group the user hasn't joined,
  /// not null — always present when the index endpoint returns it.
  final int? unreadCount;

  /// The group chat's real most-recent message, for a conversation-list
  /// style preview — see GroupResource::last_message. Only present where
  /// the backend eager-loads it (currently the groups list); null when the
  /// group's chat has no messages yet.
  final GroupLastMessage? lastMessage;

  final DateTime createdAt;

  bool get myRoleIsAdmin => myRole == 'admin';
  bool get isPrivate => visibility == 'private';

  Group copyWith({
    int? membersCount,
    bool? isMember,
    String? myRole,
    bool? joinRequestPending,
    int? pendingJoinRequestsCount,
    String? pinnedMessage,
    bool clearPinnedMessage = false,
    AppUser? pinnedBy,
    DateTime? pinnedAt,
  }) {
    return Group(
      id: id,
      name: name,
      slug: slug,
      description: description,
      category: category,
      visibility: visibility,
      isVerified: isVerified,
      coverImageUrl: coverImageUrl,
      avatarUrl: avatarUrl,
      membersCount: membersCount ?? this.membersCount,
      postsCount: postsCount,
      postsTodayCount: postsTodayCount,
      creator: creator,
      isMember: isMember ?? this.isMember,
      myRole: myRole ?? this.myRole,
      joinRequestPending: joinRequestPending ?? this.joinRequestPending,
      pendingJoinRequestsCount:
          pendingJoinRequestsCount ?? this.pendingJoinRequestsCount,
      pinnedMessage: clearPinnedMessage
          ? null
          : (pinnedMessage ?? this.pinnedMessage),
      pinnedBy: clearPinnedMessage ? null : (pinnedBy ?? this.pinnedBy),
      pinnedAt: clearPinnedMessage ? null : (pinnedAt ?? this.pinnedAt),
      unreadCount: unreadCount,
      lastMessage: lastMessage,
      createdAt: createdAt,
    );
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      visibility: json['visibility'] as String? ?? 'public',
      isVerified: json['verified'] as bool?,
      coverImageUrl: json['cover_image_url'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      membersCount: json['members_count'] as int?,
      postsCount: json['posts_count'] as int?,
      postsTodayCount: json['posts_today_count'] as int?,
      creator: json['creator'] != null
          ? AppUser.fromJson(json['creator'] as Map<String, dynamic>)
          : null,
      isMember: json['is_member'] as bool?,
      myRole: json['my_role'] as String?,
      joinRequestPending: json['join_request_pending'] as bool?,
      pendingJoinRequestsCount: json['pending_join_requests_count'] as int?,
      pinnedMessage: json['pinned_message'] as String?,
      pinnedBy: json['pinned_by'] != null
          ? AppUser.fromJson(json['pinned_by'] as Map<String, dynamic>)
          : null,
      pinnedAt: json['pinned_at'] != null
          ? DateTime.parse(json['pinned_at'] as String)
          : null,
      unreadCount: json['unread_count'] as int?,
      lastMessage: json['last_message'] != null
          ? GroupLastMessage.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// The real outcome of POST /groups/{id}/join — a public group joins
/// instantly (the fresh [Group]); a private group only ever files a
/// request (202, no group payload, since there's no membership yet) for
/// the group's admin to approve/reject.
@immutable
class JoinGroupResult {
  const JoinGroupResult.joined(Group this.group) : requested = false;

  const JoinGroupResult.requested() : group = null, requested = true;

  final Group? group;
  final bool requested;

  T when<T>({
    required T Function(Group group) joined,
    required T Function() requested,
  }) {
    return this.requested ? requested() : joined(group!);
  }
}
