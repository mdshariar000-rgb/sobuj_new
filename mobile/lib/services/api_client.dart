import 'dart:io';

import 'package:dio/dio.dart';

import '../models/agri_ai_config.dart';
import '../models/ai_conversation.dart';
import '../models/app_notification.dart';
import '../models/app_user.dart';
import '../models/comment.dart';
import '../models/enums.dart';
import '../models/event.dart';
import '../models/event_category.dart';
import '../models/event_enums.dart';
import '../models/group.dart';
import '../models/group_category.dart';
import '../models/group_join_request.dart';
import '../models/group_member.dart';
import '../models/group_message.dart';
import '../models/listing.dart';
import '../models/listing_category.dart';
import '../models/paginated_response.dart';
import '../models/post.dart';
import '../models/post_category.dart';
import '../models/report.dart';
import '../models/subscription_status.dart';
import '../models/swap_message.dart';
import '../models/swap_offer.dart';
import 'api_exception.dart';

/// The result of a successful register/login call.
class AuthResult {
  const AuthResult({required this.user, required this.token});

  final AppUser user;
  final String token;
}

/// Thin wrapper around the Laravel API. Every method throws [ApiException] on
/// failure — callers never need to know about Dio.
class ApiClient {
  const ApiClient(this._dio);

  final Dio _dio;

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
    required String passwordConfirmation,
    required double latitude,
    required double longitude,
    String? locationLabel,
    String? experienceLevel,
    String? growingSetup,
  }) {
    return _post(
      '/auth/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
        'latitude': latitude,
        'longitude': longitude,
        'location_label': ?locationLabel,
        'experience_level': ?experienceLevel,
        'growing_setup': ?growingSetup,
      },
    ).then(_parseAuthResult);
  }

  Future<AuthResult> login({required String email, required String password}) {
    return _post(
      '/auth/login',
      data: {'email': email, 'password': password},
    ).then(_parseAuthResult);
  }

  Future<void> logout() async {
    await _post('/auth/logout');
  }

  /// DELETE /api/v1/auth/me — permanently deletes the signed-in account and
  /// its data (App Store Guideline 5.1.1(v)). Requires the current password;
  /// a wrong one comes back as a 422 [ApiException] on the `password` field.
  Future<void> deleteAccount({required String password}) async {
    await _delete('/auth/me', data: {'password': password});
  }

  /// POST /api/v1/reports — files a report against content or a user.
  /// Idempotent server-side: reporting the same item twice is fine.
  Future<void> reportContent({
    required ReportTarget target,
    required int targetId,
    required ReportReason reason,
    String? details,
  }) async {
    await _post(
      '/reports',
      data: {
        'target_type': target.wireValue,
        'target_id': targetId,
        'reason': reason.wireValue,
        if (details != null && details.trim().isNotEmpty)
          'details': details.trim(),
      },
    );
  }

  /// POST /api/v1/users/{userId}/block — idempotent.
  Future<void> blockUser(int userId) async {
    await _post('/users/$userId/block');
  }

  /// DELETE /api/v1/users/{userId}/block
  Future<void> unblockUser(int userId) async {
    await _delete('/users/$userId/block');
  }

  /// GET /api/v1/blocks — users the signed-in account has blocked.
  Future<PaginatedResponse<AppUser>> blockedUsers({int page = 1}) async {
    final response = await _get('/blocks', queryParameters: {'page': page});
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      AppUser.fromJson,
    );
  }

  /// GET /api/v1/auth/me — used to restore a session on app start (validate a
  /// stored token and refresh profile data) and to detect a suspension applied
  /// after the token was issued.
  Future<AppUser> me() async {
    final response = await _get('/auth/me');
    return AppUser.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// PATCH /api/v1/auth/me — every field is individually optional, so a
  /// caller only sends what actually changed. Sent as POST with a spoofed
  /// `_method: PATCH` field rather than a literal PATCH verb: PHP never
  /// populates file uploads for a real multipart PATCH/PUT request (a
  /// platform limitation, not a Laravel one), and Laravel's own method-
  /// override convention is the standard fix — the server route is still
  /// declared as PATCH and matches correctly.
  Future<AppUser> updateProfile({
    String? name,
    String? username,
    String? bio,
    String? phone,
    String? locationLabel,
    List<String>? growingInterests,
    bool? showHandoverRadius,
    ExperienceLevel? experienceLevel,
    GrowingSetup? growingSetup,
    File? avatar,
    File? coverPhoto,
  }) async {
    final formData = FormData.fromMap({
      '_method': 'PATCH',
      'name': ?name,
      'username': ?username,
      'bio': ?bio,
      'phone': ?phone,
      'location_label': ?locationLabel,
      // '1'/'0', not the raw bool — Dio stringifies a bool to the literal
      // words "true"/"false" in multipart form data, which fails Laravel's
      // `boolean` validation rule (it only accepts 1/0/"1"/"0"), so every
      // profile save was rejected with a 422 regardless of any other field.
      'show_handover_radius': ?(showHandoverRadius != null
          ? (showHandoverRadius ? '1' : '0')
          : null),
      'experience_level': ?experienceLevel?.value,
      'growing_setup': ?growingSetup?.value,
      if (growingInterests != null) 'growing_interests': growingInterests,
      'avatar': ?(avatar != null
          ? await MultipartFile.fromFile(avatar.path)
          : null),
      'cover_photo': ?(coverPhoto != null
          ? await MultipartFile.fromFile(coverPhoto.path)
          : null),
    }, ListFormat.multiCompatible);

    final response = await _post('/auth/me', data: formData);
    return AppUser.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// GET /api/v1/listings/nearby
  Future<PaginatedResponse<Listing>> nearbyListings({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    String? category,
    TransactionType? transactionType,
    String? search,
    String? sort,
    int page = 1,
  }) async {
    final response = await _get(
      '/listings/nearby',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'radius_km': radiusKm,
        'page': page,
        if (category != null) 'category': category,
        if (transactionType != null) 'transaction_type': transactionType.value,
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
        'sort': ?sort,
      },
    );

    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      Listing.fromJson,
    );
  }

  /// POST /api/v1/listings — up to 6 photos; omit `latitude`/`longitude` to
  /// default to the poster's own location.
  Future<Listing> createListing({
    required String title,
    String? variety,
    String? description,
    ListingCondition? condition,
    required String listingType,
    required TransactionType transactionType,
    double? price,
    String? lookingFor,
    String? handoverNote,
    double? latitude,
    double? longitude,
    List<File> photos = const [],
  }) async {
    final formData = FormData.fromMap({
      'title': title,
      'variety': ?variety,
      'description': ?description,
      'condition': ?condition?.value,
      'listing_type': listingType,
      'transaction_type': transactionType.value,
      'price': ?price,
      'looking_for': ?lookingFor,
      'handover_note': ?handoverNote,
      'latitude': ?latitude,
      'longitude': ?longitude,
      'photos': [
        for (final photo in photos) await MultipartFile.fromFile(photo.path),
      ],
      // Laravel's `'photos' => ['array']` validation expects PHP's classic
      // array-upload field naming (`photos[]`, repeated) — dio's default
      // ListFormat.multi sends repeated bare `photos` fields instead, which
      // PHP collapses to just the last file rather than an array.
    }, ListFormat.multiCompatible);

    final response = await _post('/listings', data: formData);
    return Listing.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// POST /api/v1/listings/{listingId}/save
  Future<Listing> saveListing(int listingId) async {
    final response = await _post('/listings/$listingId/save');
    return Listing.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// DELETE /api/v1/listings/{listingId}/save
  Future<Listing> unsaveListing(int listingId) async {
    final response = await _delete('/listings/$listingId/save');
    return Listing.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// GET /api/v1/listings/saved — every listing the user has tapped the
  /// heart icon on, most recently saved first.
  Future<PaginatedResponse<Listing>> savedListings({int page = 1}) async {
    final response = await _get(
      '/listings/saved',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      Listing.fromJson,
    );
  }

  /// GET /api/v1/swap-offers/{swapOfferId} — used for notification-tap
  /// deep-linking (a swap-message notification only carries a
  /// swap_offer_id).
  Future<SwapOffer> swapOffer(int swapOfferId) async {
    final response = await _get('/swap-offers/$swapOfferId');
    return SwapOffer.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// POST /api/v1/listings/{listingId}/swap-offers — the real action behind
  /// Contact/Request/Propose Trade/"I Have This".
  Future<SwapOffer> createSwapOffer(int listingId, {String? note}) async {
    final response = await _post(
      '/listings/$listingId/swap-offers',
      data: {
        'offer_details': note != null && note.trim().isNotEmpty
            ? {'note': note.trim()}
            : null,
      },
    );
    return SwapOffer.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// GET /api/v1/swap-offers — offers involving the current user, either as
  /// requester or as the listing's owner.
  Future<PaginatedResponse<SwapOffer>> mySwapOffers({int page = 1}) async {
    final response = await _get(
      '/swap-offers',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      SwapOffer.fromJson,
    );
  }

  /// GET /api/v1/swap-offers/{swapOfferId}/messages
  Future<PaginatedResponse<SwapMessage>> swapOfferMessages(
    int swapOfferId, {
    int page = 1,
  }) async {
    final response = await _get(
      '/swap-offers/$swapOfferId/messages',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      SwapMessage.fromJson,
    );
  }

  /// POST /api/v1/swap-offers/{swapOfferId}/messages — [body] and [image]
  /// are each individually optional, but the server requires at least one
  /// (an image-only message with no caption is valid).
  Future<SwapMessage> sendSwapOfferMessage(
    int swapOfferId, {
    String? body,
    File? image,
  }) async {
    final response = await _post(
      '/swap-offers/$swapOfferId/messages',
      data: FormData.fromMap({
        'body': ?body,
        'image': ?(image != null
            ? await MultipartFile.fromFile(image.path)
            : null),
      }),
    );
    return SwapMessage.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// PATCH /api/v1/swap-offers/{swapOfferId}/status — Accept/Decline/Cancel/
  /// Complete, whichever transitions SwapOfferPolicy::respond() allows for
  /// the caller's side of the negotiation.
  Future<SwapOffer> updateSwapOfferStatus(
    int swapOfferId,
    SwapOfferStatus status,
  ) async {
    final response = await _patch(
      '/swap-offers/$swapOfferId/status',
      data: {'status': status.value},
    );
    return SwapOffer.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// GET /api/v1/users/{userId} — a grower's public profile (name,
  /// verification, growing setup/experience, rating — never their email or
  /// account status, which stay private to the account itself).
  Future<AppUser> userProfile(int userId) async {
    final response = await _get('/users/$userId');
    return AppUser.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// GET /api/v1/users/{userId}/listings — that grower's active listings.
  Future<PaginatedResponse<Listing>> userListings(
    int userId, {
    int page = 1,
  }) async {
    final response = await _get(
      '/users/$userId/listings',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      Listing.fromJson,
    );
  }

  /// GET /api/v1/feed — the general Home Feed (posts with no group).
  Future<PaginatedResponse<Post>> homeFeed({
    String? search,
    int? authorId,
    String? category,
    int page = 1,
  }) async {
    final response = await _get(
      '/feed',
      queryParameters: {
        'page': page,
        'search': ?search,
        'author_id': ?authorId,
        'category': ?category,
      },
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      Post.fromJson,
    );
  }

  /// GET /api/v1/listings — the signed-in user's own listings (any status),
  /// for the "My Listings" tab on their profile.
  Future<PaginatedResponse<Listing>> myListings({int page = 1}) async {
    final response = await _get('/listings', queryParameters: {'page': page});
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      Listing.fromJson,
    );
  }

  /// POST /api/v1/posts — omitting groupId posts to the general Home Feed.
  Future<Post> createPost({
    required String body,
    int? groupId,
    String? category,
    File? image,
  }) async {
    final formData = FormData.fromMap({
      'body': body,
      'group_id': ?groupId,
      'category': ?category,
      'image': ?(image != null
          ? await MultipartFile.fromFile(image.path)
          : null),
    });

    final response = await _post('/posts', data: formData);
    return Post.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// GET /api/v1/posts/{postId} — used for notification-tap deep-linking
  /// (post liked/commented/replied-to notifications only carry a post_id).
  Future<Post> post(int postId) async {
    final response = await _get('/posts/$postId');
    return Post.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> deletePost(int postId) async {
    await _delete('/posts/$postId');
  }

  /// PATCH /api/v1/posts/{postId} — only the author's own body/category/
  /// image are editable; sent as a spoofed POST + `_method: PATCH` the same
  /// way updateGroup()/updateProfile() are, since a real multipart PATCH
  /// doesn't populate PHP's $_FILES. removeImage clears an existing photo
  /// without uploading a new one; ignored when [image] is also given.
  Future<Post> updatePost(
    int postId, {
    String? body,
    String? category,
    File? image,
    bool removeImage = false,
  }) async {
    final response = await _post(
      '/posts/$postId',
      data: FormData.fromMap({
        '_method': 'PATCH',
        'body': ?body,
        'category': ?category,
        'image': ?(image != null
            ? await MultipartFile.fromFile(image.path)
            : null),
        'remove_image': ?(removeImage ? '1' : null),
      }),
    );
    return Post.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// POST /api/v1/posts/{postId}/like
  Future<Post> likePost(int postId) async {
    final response = await _post('/posts/$postId/like');
    return Post.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// DELETE /api/v1/posts/{postId}/like
  Future<Post> unlikePost(int postId) async {
    final response = await _delete('/posts/$postId/like');
    return Post.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// POST /api/v1/posts/{postId}/approve — a private group admin/creator
  /// approves a pending (or previously rejected) post.
  Future<void> approvePost(int postId) async {
    await _post('/posts/$postId/approve');
  }

  /// POST /api/v1/posts/{postId}/reject
  Future<void> rejectPost(int postId) async {
    await _post('/posts/$postId/reject');
  }

  /// GET /api/v1/posts/{postId}/comments
  Future<PaginatedResponse<Comment>> postComments(
    int postId, {
    int page = 1,
  }) async {
    final response = await _get(
      '/posts/$postId/comments',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      Comment.fromJson,
    );
  }

  /// POST /api/v1/posts/{postId}/comments — [replyToCommentId] may be any
  /// comment on this post (top-level or a reply); the server normalizes it
  /// to the thread's top-level parent and records who's being addressed.
  Future<Comment> createComment(
    int postId, {
    required String body,
    int? replyToCommentId,
  }) async {
    final response = await _post(
      '/posts/$postId/comments',
      data: {'body': body, 'reply_to_comment_id': ?replyToCommentId},
    );
    return Comment.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  Future<void> deleteComment(int commentId) async {
    await _delete('/comments/$commentId');
  }

  /// GET /api/v1/post-categories — the admin-managed list backing the Home
  /// tab's Recent/Disease Alerts/Harvests chips and the "new post" composer,
  /// not paginated (always a short reference list, not user-generated
  /// content).
  Future<List<PostCategory>> postCategories() async {
    final response = await _get('/post-categories');
    final data =
        (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((item) => PostCategory.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// GET /api/v1/listing-categories — the admin-managed list the "Create a
  /// Listing" screen picks from, not paginated (always a short reference
  /// list, not user-generated content).
  Future<List<ListingCategory>> listingCategories() async {
    final response = await _get('/listing-categories');
    final data =
        (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((item) => ListingCategory.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// GET /api/v1/group-categories — the admin-managed list the "Create a
  /// Group" screen picks from, not paginated (always a short reference
  /// list, not user-generated content).
  Future<List<GroupCategory>> groupCategories() async {
    final response = await _get('/group-categories');
    final data =
        (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((item) => GroupCategory.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// GET /api/v1/groups
  Future<PaginatedResponse<Group>> groups({
    String? search,
    String? category,
    int page = 1,
  }) async {
    final response = await _get(
      '/groups',
      queryParameters: {
        'page': page,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        'category': ?category,
      },
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      Group.fromJson,
    );
  }

  /// GET /api/v1/groups/{groupId}
  Future<Group> group(int groupId) async {
    final response = await _get('/groups/$groupId');
    return Group.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// POST /api/v1/groups
  Future<Group> createGroup({
    required String name,
    required String slug,
    String? description,
    String? category,
    bool isPrivate = false,
    File? coverImage,
    File? avatar,
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      'slug': slug,
      'description': ?description,
      'category': ?category,
      'visibility': isPrivate ? 'private' : 'public',
      'cover_image': ?(coverImage != null
          ? await MultipartFile.fromFile(coverImage.path)
          : null),
      'avatar': ?(avatar != null
          ? await MultipartFile.fromFile(avatar.path)
          : null),
    });

    final response = await _post('/groups', data: formData);
    return Group.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// POST /api/v1/groups/{groupId}/join — a public group joins instantly
  /// (200, a fresh Group); a private group only files a request (202, no
  /// group payload — there's no membership yet) for the group's admin to
  /// approve/reject.
  Future<JoinGroupResult> joinGroup(int groupId) async {
    final response = await _post('/groups/$groupId/join');
    if (response.statusCode == 202) return const JoinGroupResult.requested();
    return JoinGroupResult.joined(
      Group.fromJson(
        (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
      ),
    );
  }

  /// DELETE /api/v1/groups/{groupId}/join-requests/me — withdraws the
  /// caller's own still-pending request to join a private group.
  Future<void> cancelJoinRequest(int groupId) async {
    await _delete('/groups/$groupId/join-requests/me');
  }

  /// GET /api/v1/groups/{groupId}/join-requests — the group admin's real
  /// pending requests to moderate.
  Future<PaginatedResponse<GroupJoinRequest>> groupJoinRequests(
    int groupId, {
    int page = 1,
  }) async {
    final response = await _get(
      '/groups/$groupId/join-requests',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      GroupJoinRequest.fromJson,
    );
  }

  /// PATCH /api/v1/groups/{groupId}/join-requests/{joinRequestId}
  Future<void> decideJoinRequest(
    int groupId,
    int joinRequestId, {
    required bool approve,
  }) async {
    await _patch(
      '/groups/$groupId/join-requests/$joinRequestId',
      data: {'decision': approve ? 'approve' : 'reject'},
    );
  }

  /// POST /api/v1/groups/{groupId}/leave
  Future<void> leaveGroup(int groupId) async {
    await _post('/groups/$groupId/leave');
  }

  /// GET /api/v1/groups/{groupId}/posts — the group's discussion thread.
  Future<PaginatedResponse<Post>> groupPosts(
    int groupId, {
    int page = 1,
  }) async {
    final response = await _get(
      '/groups/$groupId/posts',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      Post.fromJson,
    );
  }

  /// GET /api/v1/groups/{groupId}/members — the real roster, admins first.
  Future<PaginatedResponse<GroupMember>> groupMembers(
    int groupId, {
    int page = 1,
  }) async {
    final response = await _get(
      '/groups/$groupId/members',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      GroupMember.fromJson,
    );
  }

  /// PATCH /api/v1/groups/{groupId} — pins/unpins the chat announcement
  /// (pass an empty string to unpin) and/or edits the group's own fields
  /// (name/description/category/visibility/cover/avatar) from Group
  /// Settings; sent as a spoofed POST + `_method: PATCH` the same way
  /// updateProfile() is, since a real multipart PATCH doesn't populate
  /// PHP's $_FILES.
  Future<Group> updateGroup(
    int groupId, {
    String? name,
    String? description,
    String? category,
    bool? isPrivate,
    File? coverImage,
    File? avatar,
    String? pinnedMessage,
  }) async {
    final response = await _post(
      '/groups/$groupId',
      data: FormData.fromMap({
        '_method': 'PATCH',
        'name': ?name,
        'description': ?description,
        'category': ?category,
        'visibility': ?(isPrivate != null
            ? (isPrivate ? 'private' : 'public')
            : null),
        'cover_image': ?(coverImage != null
            ? await MultipartFile.fromFile(coverImage.path)
            : null),
        'avatar': ?(avatar != null
            ? await MultipartFile.fromFile(avatar.path)
            : null),
        'pinned_message': ?pinnedMessage,
      }),
    );
    return Group.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// GET /api/v1/groups/{groupId}/messages — the group's real-time chat
  /// history (the live half comes from GroupRealtimeChannel).
  Future<PaginatedResponse<GroupMessage>> groupMessages(
    int groupId, {
    int page = 1,
  }) async {
    final response = await _get(
      '/groups/$groupId/messages',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      GroupMessage.fromJson,
    );
  }

  /// POST /api/v1/groups/{groupId}/messages — [body] and [image] are each
  /// individually optional, but the server requires at least one.
  Future<GroupMessage> sendGroupMessage(
    int groupId, {
    String? body,
    File? image,
  }) async {
    final response = await _post(
      '/groups/$groupId/messages',
      data: FormData.fromMap({
        'body': ?body,
        'image': ?(image != null
            ? await MultipartFile.fromFile(image.path)
            : null),
      }),
    );
    return GroupMessage.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// GET /api/v1/ai/conversations — history list; each entry has no
  /// `messages` (see AiConversation.messages doc).
  Future<PaginatedResponse<AiConversation>> aiConversations({
    int page = 1,
  }) async {
    final response = await _get(
      '/ai/conversations',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      AiConversation.fromJson,
    );
  }

  /// GET /api/v1/ai/conversations/{conversationId} — full message history.
  Future<AiConversation> aiConversation(int conversationId) async {
    final response = await _get('/ai/conversations/$conversationId');
    return AiConversation.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// POST /api/v1/ai/messages — omitting conversationId starts a new
  /// conversation. Returns the full conversation (including the just-sent
  /// user message and Gemini's reply).
  Future<AiConversation> sendAiMessage({
    int? conversationId,
    String? body,
    File? photo,
  }) async {
    final formData = FormData.fromMap({
      'conversation_id': ?conversationId,
      'body': ?body,
      'photo': ?(photo != null
          ? await MultipartFile.fromFile(photo.path)
          : null),
    });

    final response = await _post('/ai/messages', data: formData);
    return AiConversation.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// GET /api/v1/events — published events only, soonest first. month, when
  /// given, is 'YYYY-MM' and narrows to that calendar month (backs the
  /// Events tab's calendar view); category narrows to one admin-managed
  /// event category name (see EventCategory) — see EventController::index()
  /// on the backend.
  Future<PaginatedResponse<Event>> events({
    int? groupId,
    String? month,
    String? category,
    int page = 1,
  }) async {
    final response = await _get(
      '/events',
      queryParameters: {
        'page': page,
        'group_id': ?groupId,
        'month': ?month,
        'category': ?category,
      },
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      Event.fromJson,
    );
  }

  /// GET /api/v1/events/saved — events this user has bookmarked, most
  /// recently saved first, including ones that already ended — see
  /// EventController::saved() on the backend.
  Future<PaginatedResponse<Event>> savedEvents({int page = 1}) async {
    final response = await _get(
      '/events/saved',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      Event.fromJson,
    );
  }

  /// GET /api/v1/event-categories — the admin-managed list the Events tab's
  /// filter chips and the "create an event" form pick from, not paginated
  /// (always a short reference list, not user-generated content).
  Future<List<EventCategory>> eventCategories() async {
    final response = await _get('/event-categories');
    final data =
        (response.data as Map<String, dynamic>)['data'] as List<dynamic>;
    return data
        .map((item) => EventCategory.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// GET /api/v1/events/{eventId}
  Future<Event> event(int eventId) async {
    final response = await _get('/events/$eventId');
    return Event.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// POST /api/v1/events
  Future<Event> createEvent({
    int? groupId,
    required String title,
    String? description,
    required EventFormat format,
    String? category,
    File? coverImage,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
    int? capacity,
    required EventStatus status,
  }) async {
    final formData = FormData.fromMap({
      'group_id': ?groupId,
      'title': title,
      'description': ?description,
      'format': format.value,
      'category': ?category,
      'cover_image': ?(coverImage != null
          ? await MultipartFile.fromFile(coverImage.path)
          : null),
      'location': ?location,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': ?endsAt?.toIso8601String(),
      'capacity': ?capacity,
      'status': status.value,
    });

    final response = await _post('/events', data: formData);
    return Event.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// POST /api/v1/events/{eventId}/rsvp
  Future<Event> rsvpToEvent(int eventId, EventAttendeeStatus status) async {
    final response = await _post(
      '/events/$eventId/rsvp',
      data: {'status': status.value},
    );
    return Event.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// DELETE /api/v1/events/{eventId}/rsvp
  Future<void> cancelEventRsvp(int eventId) async {
    await _delete('/events/$eventId/rsvp');
  }

  /// POST /api/v1/events/{eventId}/save
  Future<Event> saveEvent(int eventId) async {
    final response = await _post('/events/$eventId/save');
    return Event.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// DELETE /api/v1/events/{eventId}/save
  Future<Event> unsaveEvent(int eventId) async {
    final response = await _delete('/events/$eventId/save');
    return Event.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// GET /api/v1/config/stripe-key — public, no auth required. Fetched at
  /// runtime rather than compiled into the app so an admin rotating the key
  /// or changing the Agri-AI Premium price via the Settings page takes
  /// effect immediately, no new APK needed.
  Future<AgriAiConfig> agriAiConfig() async {
    final response = await _get('/config/stripe-key');
    return AgriAiConfig.fromJson(response.data as Map<String, dynamic>);
  }

  /// GET /api/v1/subscriptions/me
  Future<SubscriptionStatus> subscriptionStatus() async {
    final response = await _get('/subscriptions/me');
    return SubscriptionStatus.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// POST /api/v1/subscriptions — `paymentMethodId` comes from
  /// flutter_stripe's on-device card tokenization; card details never pass
  /// through this server. May come back as a 202 "requires 3-D Secure"
  /// response instead of an immediate 201 — see [SubscribeResult].
  Future<SubscribeResult> createSubscription({
    required String plan,
    required String paymentMethodId,
  }) async {
    final response = await _post(
      '/subscriptions',
      data: {'plan': plan, 'payment_method': paymentMethodId},
    );
    final body = response.data as Map<String, dynamic>;

    if (response.statusCode == 202) {
      return SubscribeResult.requiresAction(
        body['payment_intent_client_secret'] as String,
      );
    }

    return SubscribeResult.success(
      SubscriptionStatus.fromJson(body['data'] as Map<String, dynamic>),
    );
  }

  /// DELETE /api/v1/subscriptions/me — cancels at the end of the current
  /// paid/trial period; access continues until then.
  Future<SubscriptionStatus> cancelSubscription() async {
    final response = await _delete('/subscriptions/me');
    return SubscriptionStatus.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// POST /api/v1/device-tokens — registers (or re-registers) this device's
  /// FCM token against the signed-in user. Safe to call repeatedly (e.g. on
  /// every login/session-restore, and again on FCM's own token-refresh
  /// event) — the backend upserts by token.
  Future<void> registerDeviceToken(
    String token, {
    String platform = 'android',
  }) async {
    await _post('/device-tokens', data: {'token': token, 'platform': platform});
  }

  /// DELETE /api/v1/device-tokens — called on logout so a shared/reused
  /// device stops receiving this user's pushes once they've signed out.
  Future<void> unregisterDeviceToken(String token) async {
    await _delete('/device-tokens', data: {'token': token});
  }

  /// GET /api/v1/notifications — the real in-app notification inbox,
  /// newest first.
  Future<PaginatedResponse<AppNotification>> notifications({
    int page = 1,
  }) async {
    final response = await _get(
      '/notifications',
      queryParameters: {'page': page},
    );
    return PaginatedResponse.fromJson(
      response.data as Map<String, dynamic>,
      AppNotification.fromJson,
    );
  }

  /// GET /api/v1/notifications/unread-count — backs the bell icon's badge.
  Future<int> unreadNotificationCount() async {
    final response = await _get('/notifications/unread-count');
    return (response.data as Map<String, dynamic>)['unread_count'] as int;
  }

  /// POST /api/v1/notifications/{notificationId}/read
  Future<AppNotification> markNotificationRead(int notificationId) async {
    final response = await _post('/notifications/$notificationId/read');
    return AppNotification.fromJson(
      (response.data as Map<String, dynamic>)['data'] as Map<String, dynamic>,
    );
  }

  /// POST /api/v1/notifications/read-all
  Future<void> markAllNotificationsRead() async {
    await _post('/notifications/read-all');
  }

  AuthResult _parseAuthResult(Response<dynamic> response) {
    final body = response.data as Map<String, dynamic>;

    return AuthResult(
      user: AppUser.fromJson(body['data'] as Map<String, dynamic>),
      token: body['token'] as String,
    );
  }

  Future<Response<dynamic>> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response<dynamic>> _post(String path, {Object? data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response<dynamic>> _delete(String path, {Object? data}) async {
    try {
      return await _dio.delete(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response<dynamic>> _patch(String path, {Object? data}) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}
