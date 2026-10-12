import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shobuj_mobile/models/app_notification.dart';
import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/models/comment.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/event.dart';
import 'package:shobuj_mobile/models/event_category.dart';
import 'package:shobuj_mobile/models/event_enums.dart';
import 'package:shobuj_mobile/models/event_review.dart';
import 'package:shobuj_mobile/models/feed_marketplace.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/models/group_category.dart';
import 'package:shobuj_mobile/models/group_join_request.dart';
import 'package:shobuj_mobile/models/group_member.dart';
import 'package:shobuj_mobile/models/group_message.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/listing_category.dart';
import 'package:shobuj_mobile/models/listing_review.dart';
import 'package:shobuj_mobile/models/message_reaction.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/post.dart';
import 'package:shobuj_mobile/models/report.dart';
import 'package:shobuj_mobile/models/search_results.dart';
import 'package:shobuj_mobile/models/sowing_guide_month.dart';
import 'package:shobuj_mobile/models/swap_message.dart';
import 'package:shobuj_mobile/models/swap_offer.dart';
import 'package:shobuj_mobile/models/uk_address.dart';
import 'package:shobuj_mobile/services/api_client.dart';
import 'package:shobuj_mobile/services/social_sign_in_service.dart';
import 'package:shobuj_mobile/services/api_exception.dart';

AppUser buildFakeUser({
  int id = 1,
  String name = 'Rina',
  String email = 'rina@example.com',
  int? followersCount,
  int? followingCount,
  bool? isFollowing,
  bool hasPassword = true,
  List<String> signedInWith = const [],
}) {
  return AppUser(
    id: id,
    name: name,
    email: email,
    hasPassword: hasPassword,
    signedInWith: signedInWith,
    isSuspended: false,
    suspensionReason: null,
    isVerified: false,
    ratingAvg: 0,
    followersCount: followersCount,
    followingCount: followingCount,
    isFollowing: isFollowing,
    createdAt: DateTime(2026, 1, 1),
  );
}

/// A controllable stand-in for ApiClient's auth methods. ApiClient isn't
/// `final`, so overriding just the methods a given test needs is enough —
/// every unmapped call throws UnimplementedError to fail loudly rather than
/// silently hitting the real network.
class FakeApiClient extends ApiClient {
  FakeApiClient() : super(Dio());

  AppUser? meResult;
  ApiException? meError;

  AuthResult? loginResult;
  ApiException? loginError;

  AuthResult? registerResult;
  ApiException? registerError;
  String? lastRegisterLocationLabel;
  List<String>? lastRegisterInterests;
  UkAddress? lastRegisterAddress;

  bool logoutCalled = false;

  @override
  Future<AppUser> me() async {
    if (meError != null) throw meError!;
    if (meResult != null) return meResult!;
    throw const ApiException(
      message: 'FakeApiClient.me: no result configured',
      statusCode: 401,
    );
  }

  AppUser? userProfileResult;
  ApiException? userProfileError;
  PaginatedResponse<Listing>? userListingsResult;
  ApiException? userListingsError;

  /// Backs [SellerProfileScreen] — the app-wide "view this person's
  /// profile" destination, reached from any avatar/name tap.
  @override
  Future<AppUser> userProfile(int userId) async {
    if (userProfileError != null) throw userProfileError!;
    return userProfileResult ?? buildFakeUser(id: userId, name: 'Grower');
  }

  @override
  Future<PaginatedResponse<Listing>> userListings(
    int userId, {
    int page = 1,
  }) async {
    if (userListingsError != null) throw userListingsError!;
    return userListingsResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  /// Backs [UserProfileNotifier.toggleFollow] — set [followUserResult]/
  /// [unfollowUserResult] (or the matching error) per test; defaults to
  /// flipping [buildFakeUser]'s is_following if neither is configured.
  final followedUserIds = <int>[];
  final unfollowedUserIds = <int>[];
  AppUser? followUserResult;
  ApiException? followUserError;
  AppUser? unfollowUserResult;
  ApiException? unfollowUserError;
  List<AppUser> userFollowersResult = [];
  List<AppUser> userFollowingResult = [];

  @override
  Future<AppUser> followUser(int userId) async {
    if (followUserError != null) throw followUserError!;
    followedUserIds.add(userId);
    return followUserResult ??
        buildFakeUser(id: userId, name: 'Grower', isFollowing: true);
  }

  @override
  Future<AppUser> unfollowUser(int userId) async {
    if (unfollowUserError != null) throw unfollowUserError!;
    unfollowedUserIds.add(userId);
    return unfollowUserResult ??
        buildFakeUser(id: userId, name: 'Grower', isFollowing: false);
  }

  @override
  Future<PaginatedResponse<AppUser>> userFollowers(
    int userId, {
    int page = 1,
  }) async {
    return PaginatedResponse(
      data: userFollowersResult,
      currentPage: 1,
      lastPage: 1,
      total: userFollowersResult.length,
    );
  }

  @override
  Future<PaginatedResponse<AppUser>> userFollowing(
    int userId, {
    int page = 1,
  }) async {
    return PaginatedResponse(
      data: userFollowingResult,
      currentPage: 1,
      lastPage: 1,
      total: userFollowingResult.length,
    );
  }

  SocialConfig socialConfigResult = SocialConfig.off;

  @override
  Future<SocialConfig> socialConfig() async => socialConfigResult;

  /// Answers POST /auth/social: [socialSignupResult] once an address is
  /// sent, else [socialLoginResult].
  SocialLoginResult? socialLoginResult;
  AuthResult? socialSignupResult;
  ApiException? socialLoginError;
  final socialLoginCalls = <Map<String, Object?>>[];

  @override
  Future<SocialLoginResult> socialLogin({
    required String provider,
    required String idToken,
    String? nonce,
    String? name,
    double? latitude,
    double? longitude,
    String? locationLabel,
    UkAddress? address,
  }) async {
    socialLoginCalls.add({
      'provider': provider,
      'idToken': idToken,
      'nonce': nonce,
      'name': name,
      'latitude': latitude,
      'address': address,
    });
    if (socialLoginError != null) throw socialLoginError!;
    if (address != null) {
      return SocialSignedIn(socialSignupResult!, isNewUser: true);
    }
    return socialLoginResult!;
  }

  @override
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    if (loginError != null) throw loginError!;
    return loginResult!;
  }

  @override
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
    List<String> growingInterests = const [],
    UkAddress? address,
  }) async {
    lastRegisterLocationLabel = locationLabel;
    lastRegisterAddress = address;
    lastRegisterInterests = growingInterests;
    if (registerError != null) throw registerError!;
    return registerResult!;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  String? lastDeletedAccountPassword;
  ApiException? deleteAccountError;

  ({String? provider, String? idToken, String? nonce, String? code})?
  lastDeletedAccountToken;

  @override
  Future<void> deleteAccount({
    String? password,
    String? provider,
    String? idToken,
    String? nonce,
    String? authorizationCode,
  }) async {
    lastDeletedAccountPassword = password;
    if (idToken != null) {
      lastDeletedAccountToken = (
        provider: provider,
        idToken: idToken,
        nonce: nonce,
        code: authorizationCode,
      );
    }
    if (deleteAccountError != null) throw deleteAccountError!;
  }

  final reportsFiled =
      <
        ({
          ReportTarget target,
          int targetId,
          ReportReason reason,
          String? details,
        })
      >[];
  ApiException? reportError;

  @override
  Future<void> reportContent({
    required ReportTarget target,
    required int targetId,
    required ReportReason reason,
    String? details,
  }) async {
    if (reportError != null) throw reportError!;
    reportsFiled.add((
      target: target,
      targetId: targetId,
      reason: reason,
      details: details,
    ));
  }

  final blockedUserIds = <int>[];
  final unblockedUserIds = <int>[];
  List<AppUser> blockedUsersResult = [];

  @override
  Future<void> blockUser(int userId) async {
    blockedUserIds.add(userId);
  }

  @override
  Future<void> unblockUser(int userId) async {
    unblockedUserIds.add(userId);
    blockedUsersResult = blockedUsersResult
        .where((user) => user.id != userId)
        .toList();
  }

  @override
  Future<PaginatedResponse<AppUser>> blockedUsers({int page = 1}) async {
    return PaginatedResponse(
      data: blockedUsersResult,
      currentPage: 1,
      lastPage: 1,
      total: blockedUsersResult.length,
    );
  }

  /// Defaults to an empty result so tests that land on the Discovery screen
  /// as a side effect (e.g. after login) don't trip a real network call —
  /// override per-test when a case actually needs to assert on listings.
  @override
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
    return const PaginatedResponse(
      data: [],
      currentPage: 1,
      lastPage: 1,
      total: 0,
    );
  }

  AppUser? updateProfileResult;
  ApiException? updateProfileError;
  Map<String, dynamic>? lastUpdateProfileArgs;

  @override
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
    UkAddress? address,
    double? latitude,
    double? longitude,
  }) async {
    lastUpdateProfileArgs = {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'name': name,
      'username': username,
      'bio': bio,
      'phone': phone,
      'locationLabel': locationLabel,
      'growingInterests': growingInterests,
      'showHandoverRadius': showHandoverRadius,
      'avatar': avatar,
      'coverPhoto': coverPhoto,
    };
    if (updateProfileError != null) throw updateProfileError!;
    return updateProfileResult!;
  }

  PaginatedResponse<Listing>? myListingsResult;
  ApiException? myListingsError;

  /// Defaults to an empty result for the same reason as [nearbyListings] —
  /// most tests land on a screen that fetches this as a side effect without
  /// caring about its contents.
  @override
  Future<PaginatedResponse<Listing>> myListings({int page = 1}) async {
    if (myListingsError != null) throw myListingsError!;
    return myListingsResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  PaginatedResponse<Post>? userPostsResult;
  int? lastUserPostsId;

  @override
  Future<PaginatedResponse<Post>> userPosts(int userId, {int page = 1}) async {
    lastUserPostsId = userId;
    return userPostsResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  Post? createPostResult;
  ApiException? createPostError;
  int? lastCreatePostGroupId;

  @override
  Future<Post> createPost({
    required String body,
    required int groupId,
    File? image,
  }) async {
    lastCreatePostGroupId = groupId;
    if (createPostError != null) throw createPostError!;
    return createPostResult!;
  }

  bool deletePostCalled = false;

  @override
  Future<void> deletePost(int postId) async {
    deletePostCalled = true;
  }

  Post? updatePostResult;
  ApiException? updatePostError;
  int? lastUpdatePostId;
  String? lastUpdatePostBody;
  bool? lastUpdatePostRemoveImage;

  @override
  Future<Post> updatePost(
    int postId, {
    String? body,
    File? image,
    bool removeImage = false,
  }) async {
    lastUpdatePostId = postId;
    lastUpdatePostBody = body;
    lastUpdatePostRemoveImage = removeImage;
    if (updatePostError != null) throw updatePostError!;
    return updatePostResult!;
  }

  Post? likePostResult;
  Post? unlikePostResult;
  ApiException? likePostError;
  int? likedPostId;
  int? unlikedPostId;

  @override
  Future<Post> likePost(int postId) async {
    likedPostId = postId;
    if (likePostError != null) throw likePostError!;
    return likePostResult!;
  }

  @override
  Future<Post> unlikePost(int postId) async {
    unlikedPostId = postId;
    if (likePostError != null) throw likePostError!;
    return unlikePostResult!;
  }

  FeedMarketplace? feedMarketplaceResult;
  ApiException? feedMarketplaceError;
  int feedMarketplaceCalls = 0;

  /// Empty by default, so feed tests that don't care see plain posts.
  @override
  Future<FeedMarketplace> feedMarketplace() async {
    feedMarketplaceCalls++;
    if (feedMarketplaceError != null) throw feedMarketplaceError!;
    return feedMarketplaceResult ?? const FeedMarketplace();
  }

  /// What GET /listings/{id} returns — the listing detail screen refreshes
  /// itself from it. Unset means the fetch fails and the screen keeps the
  /// listing it was given.
  Listing? listingResult;

  @override
  Future<Listing> listing(int listingId) async {
    return listingResult ??
        (throw const ApiException(message: 'Listing not found.'));
  }

  Listing? updateListingResult;
  ListingStatus? lastUpdatedListingStatus;
  int? lastUpdatedListingQuantity;
  List<int> lastRemovedPhotoIds = const [];
  @override
  Future<Listing> updateListing(
    int listingId, {
    String? title,
    String? description,
    String? listingType,
    double? price,
    int? quantity,
    String? contact,
    String? lookingFor,
    ListingStatus? status,
    List<File> newPhotos = const [],
    List<int> removePhotoIds = const [],
  }) async {
    lastUpdatedListingStatus = status;
    lastUpdatedListingQuantity = quantity;
    lastRemovedPhotoIds = removePhotoIds;
    return updateListingResult!;
  }

  int? deletedListingId;
  @override
  Future<void> deleteListing(int listingId) async {
    deletedListingId = listingId;
  }

  final savedListingIds = <int>[];
  final unsavedListingIds = <int>[];
  ApiException? saveListingError;

  /// Echoes back the listing from [feedMarketplaceResult] with its new
  /// saved state, like the real endpoint.
  Listing _savedCopy(int listingId, bool isSaved) {
    final all = [
      ...?feedMarketplaceResult?.nearby,
      ...?feedMarketplaceResult?.fromFollowing,
    ];
    return all
        .firstWhere((listing) => listing.id == listingId)
        .copyWith(isSaved: isSaved);
  }

  @override
  Future<Listing> saveListing(int listingId) async {
    savedListingIds.add(listingId);
    if (saveListingError != null) throw saveListingError!;
    return _savedCopy(listingId, true);
  }

  @override
  Future<Listing> unsaveListing(int listingId) async {
    unsavedListingIds.add(listingId);
    if (saveListingError != null) throw saveListingError!;
    return _savedCopy(listingId, false);
  }

  PaginatedResponse<Comment>? postCommentsResult;
  ApiException? postCommentsError;

  @override
  Future<PaginatedResponse<Comment>> postComments(
    int postId, {
    int page = 1,
  }) async {
    if (postCommentsError != null) throw postCommentsError!;
    return postCommentsResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  Comment? createCommentResult;
  ApiException? createCommentError;
  int? lastReplyToCommentId;

  @override
  Future<Comment> createComment(
    int postId, {
    required String body,
    int? replyToCommentId,
  }) async {
    lastReplyToCommentId = replyToCommentId;
    if (createCommentError != null) throw createCommentError!;
    return createCommentResult!;
  }

  bool deleteCommentCalled = false;

  @override
  Future<void> deleteComment(int commentId) async {
    deleteCommentCalled = true;
  }

  PaginatedResponse<ListingReview>? listingReviewsResult;
  ApiException? listingReviewsError;

  @override
  Future<PaginatedResponse<ListingReview>> listingReviews(
    int listingId, {
    int page = 1,
  }) async {
    if (listingReviewsError != null) throw listingReviewsError!;
    return listingReviewsResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  ListingReview? submitListingReviewResult;
  ApiException? submitListingReviewError;
  int? lastSubmitListingReviewRating;
  String? lastSubmitListingReviewComment;

  @override
  Future<ListingReview> submitListingReview(
    int listingId, {
    required int rating,
    String? comment,
  }) async {
    lastSubmitListingReviewRating = rating;
    lastSubmitListingReviewComment = comment;
    if (submitListingReviewError != null) throw submitListingReviewError!;
    return submitListingReviewResult!;
  }

  bool deleteListingReviewCalled = false;
  int? lastDeletedListingReviewId;

  @override
  Future<void> deleteListingReview(int listingId, int reviewId) async {
    deleteListingReviewCalled = true;
    lastDeletedListingReviewId = reviewId;
  }

  List<SowingGuideMonth>? sowingGuideResult;
  ApiException? sowingGuideError;

  /// Defaults to all 12 months so "What can you grow now?" renders whatever
  /// month the test happens to run in.
  @override
  Future<List<SowingGuideMonth>> sowingGuide() async {
    if (sowingGuideError != null) throw sowingGuideError!;
    return sowingGuideResult ??
        [
          for (var month = 1; month <= 12; month++)
            SowingGuideMonth(
              month: month,
              outdoors: const ['Garlic', 'Broad beans'],
              underCover: const ['Microgreens'],
            ),
        ];
  }

  List<ListingCategory>? listingCategoriesResult;
  ApiException? listingCategoriesError;

  /// Defaults to a real-looking non-empty list for the same reason as
  /// [groupCategories] — reachable by default so tests that land on a screen
  /// using it as a side effect (e.g. the Discovery category chips or the
  /// create-listing category picker) don't need to stub it.
  @override
  Future<List<ListingCategory>> listingCategories() async {
    if (listingCategoriesError != null) throw listingCategoriesError!;
    return listingCategoriesResult ??
        const [
          ListingCategory(id: 1, name: 'Seeds & Scions'),
          ListingCategory(id: 2, name: 'Live Plants & Saplings'),
          ListingCategory(id: 3, name: 'Organic Fertilizers'),
          ListingCategory(id: 4, name: 'Farm Tools & Equipment'),
          ListingCategory(id: 5, name: 'Harvest & Produce'),
          ListingCategory(id: 6, name: 'Compost & Soils'),
        ];
  }

  List<GroupCategory>? groupCategoriesResult;
  ApiException? groupCategoriesError;

  /// Defaults to a real-looking non-empty list for the same reason as
  /// [groups] — reachable by default so tests that land on a screen using
  /// it as a side effect (e.g. the category picker) don't need to stub it.
  @override
  Future<List<GroupCategory>> groupCategories() async {
    if (groupCategoriesError != null) throw groupCategoriesError!;
    return groupCategoriesResult ??
        const [
          GroupCategory(id: 1, name: 'Vegetable Growing'),
          GroupCategory(id: 2, name: 'Fruit & Orchard'),
          GroupCategory(id: 3, name: 'Hydroponics & Tech'),
        ];
  }

  PaginatedResponse<Group>? groupsResult;
  ApiException? groupsError;
  Map<String, dynamic>? lastGroupsCallArgs;

  /// Defaults to an empty result for the same reason as [homeFeed] — Groups
  /// is a reachable tab by default, so most tests that land there as a side
  /// effect shouldn't trip a real network call.
  @override
  Future<PaginatedResponse<Group>> groups({
    String? search,
    String? category,
    String? membership,
    int page = 1,
  }) async {
    lastGroupsCallArgs = {'search': search, 'category': category, 'page': page};
    if (groupsError != null) throw groupsError!;
    final all =
        groupsResult ??
        const PaginatedResponse<Group>(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
    if (membership == null) return all;
    // Like the server's ?membership=mine|others split.
    final wantMine = membership == 'mine';
    final data = all.data
        .where((g) => (g.isMember ?? false) == wantMine)
        .toList();
    return PaginatedResponse(
      data: data,
      currentPage: all.currentPage,
      lastPage: all.lastPage,
      total: data.length,
    );
  }

  Group? groupResult;
  ApiException? groupError;

  @override
  Future<Group> group(int groupId) async {
    if (groupError != null) throw groupError!;
    return groupResult!;
  }

  Group? createGroupResult;
  ApiException? createGroupError;
  String? lastCreateGroupCategory;
  bool? lastCreateGroupIsPrivate;

  @override
  Future<Group> createGroup({
    required String name,
    required String slug,
    String? description,
    String? category,
    bool isPrivate = false,
    File? coverImage,
    File? avatar,
  }) async {
    lastCreateGroupCategory = category;
    lastCreateGroupIsPrivate = isPrivate;
    if (createGroupError != null) throw createGroupError!;
    return createGroupResult!;
  }

  Group? joinGroupResult;

  /// When true, [joinGroup] returns [JoinGroupResult.requested] instead of
  /// [joinGroupResult] — simulates a private group's real 202 response.
  bool joinGroupReturnsRequest = false;
  ApiException? joinGroupError;
  int? joinedGroupId;

  @override
  Future<JoinGroupResult> joinGroup(int groupId) async {
    joinedGroupId = groupId;
    if (joinGroupError != null) throw joinGroupError!;
    if (joinGroupReturnsRequest) return const JoinGroupResult.requested();
    return JoinGroupResult.joined(joinGroupResult!);
  }

  int? canceledJoinRequestGroupId;
  ApiException? cancelJoinRequestError;

  @override
  Future<void> cancelJoinRequest(int groupId) async {
    canceledJoinRequestGroupId = groupId;
    if (cancelJoinRequestError != null) throw cancelJoinRequestError!;
  }

  PaginatedResponse<GroupJoinRequest>? groupJoinRequestsResult;
  ApiException? groupJoinRequestsError;

  @override
  Future<PaginatedResponse<GroupJoinRequest>> groupJoinRequests(
    int groupId, {
    int page = 1,
  }) async {
    if (groupJoinRequestsError != null) throw groupJoinRequestsError!;
    return groupJoinRequestsResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  int? lastDecidedJoinRequestId;
  bool? lastJoinRequestDecisionApprove;
  ApiException? decideJoinRequestError;

  @override
  Future<void> decideJoinRequest(
    int groupId,
    int joinRequestId, {
    required bool approve,
  }) async {
    lastDecidedJoinRequestId = joinRequestId;
    lastJoinRequestDecisionApprove = approve;
    if (decideJoinRequestError != null) throw decideJoinRequestError!;
  }

  int? leftGroupId;
  ApiException? leaveGroupError;

  @override
  Future<void> leaveGroup(int groupId) async {
    leftGroupId = groupId;
    if (leaveGroupError != null) throw leaveGroupError!;
  }

  Group? updateGroupResult;
  ApiException? updateGroupError;
  String? lastUpdateGroupPinnedMessage;
  bool? lastUpdateGroupIsPrivate;

  @override
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
    lastUpdateGroupPinnedMessage = pinnedMessage;
    lastUpdateGroupIsPrivate = isPrivate;
    if (updateGroupError != null) throw updateGroupError!;
    return updateGroupResult!;
  }

  int? lastApprovedPostId;
  ApiException? approvePostError;

  @override
  Future<void> approvePost(int postId) async {
    lastApprovedPostId = postId;
    if (approvePostError != null) throw approvePostError!;
  }

  int? lastRejectedPostId;
  ApiException? rejectPostError;

  @override
  Future<void> rejectPost(int postId) async {
    lastRejectedPostId = postId;
    if (rejectPostError != null) throw rejectPostError!;
  }

  PaginatedResponse<GroupMember>? groupMembersResult;
  ApiException? groupMembersError;

  @override
  Future<PaginatedResponse<GroupMember>> groupMembers(
    int groupId, {
    int page = 1,
  }) async {
    if (groupMembersError != null) throw groupMembersError!;
    return groupMembersResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  PaginatedResponse<GroupMessage>? groupMessagesResult;
  ApiException? groupMessagesError;

  @override
  Future<PaginatedResponse<GroupMessage>> groupMessages(
    int groupId, {
    int page = 1,
  }) async {
    if (groupMessagesError != null) throw groupMessagesError!;
    return groupMessagesResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  GroupMessage? sendGroupMessageResult;
  ApiException? sendGroupMessageError;
  String? lastSentGroupMessageBody;
  List<File> lastSentGroupMessageImages = const [];
  int? lastSentGroupMessageReplyToId;

  @override
  Future<GroupMessage> sendGroupMessage(
    int groupId, {
    String? body,
    List<File> images = const [],
    int? replyToId,
  }) async {
    lastSentGroupMessageBody = body;
    lastSentGroupMessageImages = images;
    lastSentGroupMessageReplyToId = replyToId;
    if (sendGroupMessageError != null) throw sendGroupMessageError!;
    return sendGroupMessageResult!;
  }

  List<AppUser> suggestedUsersResult = const [];
  List<Group> suggestedGroupsResult = const [];

  @override
  Future<List<AppUser>> suggestedUsers() async => suggestedUsersResult;

  String? suggestedGroupsCity;

  @override
  Future<SuggestedGroups> suggestedGroups() async =>
      SuggestedGroups(city: suggestedGroupsCity, groups: suggestedGroupsResult);

  /// Every reaction call as (messageId, emoji) — emoji null means removed.
  final List<(int, String?)> reactionCalls = [];
  List<MessageReaction>? reactionResult;
  ApiException? reactionError;

  @override
  Future<List<MessageReaction>> setGroupMessageReaction(
    int groupId,
    int messageId,
    String? emoji,
  ) async {
    reactionCalls.add((messageId, emoji));
    if (reactionError != null) throw reactionError!;
    return reactionResult ?? const [];
  }

  @override
  Future<List<MessageReaction>> setSwapOfferMessageReaction(
    int swapOfferId,
    int messageId,
    String? emoji,
  ) async {
    reactionCalls.add((messageId, emoji));
    if (reactionError != null) throw reactionError!;
    return reactionResult ?? const [];
  }

  PaginatedResponse<SwapOffer>? mySwapOffersResult;
  ApiException? mySwapOffersError;

  /// Defaults to an empty result for the same reason as [groupMessages] —
  /// the Messages inbox is a reachable tab by default.
  @override
  Future<PaginatedResponse<SwapOffer>> mySwapOffers({int page = 1}) async {
    if (mySwapOffersError != null) throw mySwapOffersError!;
    return mySwapOffersResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  PaginatedResponse<SwapMessage>? swapOfferMessagesResult;
  ApiException? swapOfferMessagesError;

  @override
  Future<PaginatedResponse<SwapMessage>> swapOfferMessages(
    int swapOfferId, {
    int page = 1,
  }) async {
    if (swapOfferMessagesError != null) throw swapOfferMessagesError!;
    return swapOfferMessagesResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  SwapMessage? sendSwapOfferMessageResult;
  ApiException? sendSwapOfferMessageError;
  String? lastSentSwapOfferMessageBody;
  List<File> lastSentSwapOfferMessageImages = const [];
  int? lastSentSwapOfferMessageReplyToId;

  /// When set, the send waits for it — to deliver a realtime echo while the
  /// request is still in flight.
  Completer<void>? sendSwapOfferMessageGate;

  @override
  Future<SwapMessage> sendSwapOfferMessage(
    int swapOfferId, {
    String? body,
    List<File> images = const [],
    int? replyToId,
  }) async {
    lastSentSwapOfferMessageBody = body;
    lastSentSwapOfferMessageImages = images;
    lastSentSwapOfferMessageReplyToId = replyToId;
    await sendSwapOfferMessageGate?.future;
    if (sendSwapOfferMessageError != null) throw sendSwapOfferMessageError!;
    return sendSwapOfferMessageResult!;
  }

  PaginatedResponse<Post>? groupPostsResult;
  ApiException? groupPostsError;

  @override
  Future<PaginatedResponse<Post>> groupPosts(
    int groupId, {
    int page = 1,
  }) async {
    if (groupPostsError != null) throw groupPostsError!;
    return groupPostsResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  PaginatedResponse<Event>? eventsResult;
  ApiException? eventsError;
  String? lastEventsMonth;
  String? lastEventsCategory;
  bool? lastEventsForYou;
  String? lastEventsSearch;
  List<Event> goingEventsResult = const [];

  /// Per-month results for the calendar view — keyed by 'YYYY-MM'. Takes
  /// priority over [eventsResult] when the requested month has an entry, so
  /// calendar tests can give different months different events.
  Map<String, PaginatedResponse<Event>>? eventsByMonth;

  /// Defaults to an empty result for the same reason as [homeFeed]/[groups]
  /// — Events is a reachable tab by default.
  @override
  Future<PaginatedResponse<Event>> events({
    int? groupId,
    String? month,
    String? category,
    bool forYou = false,
    String? search,
    bool going = false,
    int page = 1,
  }) async {
    lastEventsMonth = month;
    lastEventsCategory = category;
    lastEventsForYou = forYou;
    lastEventsSearch = search;
    if (eventsError != null) throw eventsError!;
    if (going) {
      return PaginatedResponse(
        data: goingEventsResult,
        currentPage: 1,
        lastPage: 1,
        total: goingEventsResult.length,
      );
    }
    if (month != null && eventsByMonth?.containsKey(month) == true) {
      return eventsByMonth![month]!;
    }
    return eventsResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  List<EventCategory> eventCategoriesResult = const [];

  @override
  Future<List<EventCategory>> eventCategories() async => eventCategoriesResult;

  Event? eventResult;
  ApiException? eventError;

  @override
  Future<Event> event(int eventId) async {
    if (eventError != null) throw eventError!;
    return eventResult!;
  }

  Event? createEventResult;
  ApiException? createEventError;

  @override
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
    double? registrationFee,
    List<DateTime> proposedDates = const [],
    required EventStatus status,
  }) async {
    lastCreateEventFee = registrationFee;
    lastCreateEventProposedDates = proposedDates;
    lastCreateEventEndsAt = endsAt;
    if (createEventError != null) throw createEventError!;
    return createEventResult!;
  }

  double? lastCreateEventFee;
  List<DateTime>? lastCreateEventProposedDates;
  DateTime? lastCreateEventEndsAt;
  int? lastUpdatedEventId;
  EventStatus? lastUpdatedEventStatus;
  DateTime? lastUpdatedEventStartsAt;
  DateTime? lastUpdatedEventEndsAt;

  @override
  Future<Event> updateEvent(
    int eventId, {
    required String title,
    String? description,
    required EventFormat format,
    String? category,
    File? coverImage,
    String? location,
    required DateTime startsAt,
    DateTime? endsAt,
    int? capacity,
    double? registrationFee,
    List<DateTime> proposedDates = const [],
    required EventStatus status,
  }) async {
    lastUpdatedEventId = eventId;
    lastUpdatedEventStatus = status;
    lastUpdatedEventStartsAt = startsAt;
    lastUpdatedEventEndsAt = endsAt;
    if (createEventError != null) throw createEventError!;
    return createEventResult!;
  }

  List<Event> savedEventsResult = const [];

  @override
  Future<PaginatedResponse<Event>> savedEvents({int page = 1}) async =>
      PaginatedResponse(
        data: savedEventsResult,
        currentPage: 1,
        lastPage: 1,
        total: savedEventsResult.length,
      );

  List<Event> myDraftsResult = const [];
  List<Event> hostingEventsResult = const [];

  @override
  Future<PaginatedResponse<Event>> myEvents({
    EventStatus? status,
    int page = 1,
  }) async {
    final data = status == EventStatus.published
        ? hostingEventsResult
        : myDraftsResult;
    return PaginatedResponse(
      data: data,
      currentPage: 1,
      lastPage: 1,
      total: data.length,
    );
  }

  Group? eventChatResult;
  ApiException? eventChatError;

  @override
  Future<Group> eventChat(int eventId) async {
    if (eventChatError != null) throw eventChatError!;
    return eventChatResult!;
  }

  List<EventReview> eventReviewsResult = [];
  final List<({int eventId, int? rating, String? body})> reviewsPosted = [];

  @override
  Future<PaginatedResponse<EventReview>> eventReviews(
    int eventId, {
    int page = 1,
  }) async {
    return PaginatedResponse(
      data: eventReviewsResult,
      currentPage: 1,
      lastPage: 1,
      total: eventReviewsResult.length,
    );
  }

  @override
  Future<EventReview> reviewEvent(
    int eventId, {
    int? rating,
    String? body,
  }) async {
    reviewsPosted.add((eventId: eventId, rating: rating, body: body));
    final review = EventReview(
      id: 100 + reviewsPosted.length,
      eventId: eventId,
      rating: rating,
      body: body,
      user: meResult,
      createdAt: DateTime.now(),
    );
    eventReviewsResult = [review, ...eventReviewsResult];
    return review;
  }

  final List<int> deletedEventReviewIds = [];

  @override
  Future<void> deleteEventReview(int eventId, int reviewId) async {
    deletedEventReviewIds.add(reviewId);
    eventReviewsResult = [
      for (final review in eventReviewsResult)
        if (review.id != reviewId) review,
    ];
  }

  final List<({String name, String? description})> groupRequests = [];

  @override
  Future<void> requestGroup({required String name, String? description}) async {
    groupRequests.add((name: name, description: description));
  }

  /// Null by default: lookups "not set up" (503), so address forms in other
  /// tests open the lines to type by hand after Find address.
  List<AddressSuggestion>? postcodeAddressesResult;
  ApiException? postcodeAddressesError;
  String? lastPostcodeLookup;

  @override
  Future<List<AddressSuggestion>> postcodeAddresses(String postcode) async {
    lastPostcodeLookup = postcode;
    if (postcodeAddressesError != null) throw postcodeAddressesError!;
    return postcodeAddressesResult ??
        (throw const ApiException(
          message: 'Address lookup is unavailable right now.',
          statusCode: 503,
        ));
  }

  final List<String> passwordResetCodeEmails = [];
  ({String email, String code, String password})? lastPasswordReset;
  ApiException? resetPasswordError;

  @override
  Future<void> sendPasswordResetCode(String email) async {
    passwordResetCodeEmails.add(email);
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String password,
  }) async {
    if (resetPasswordError != null) throw resetPasswordError!;
    lastPasswordReset = (email: email, code: code, password: password);
  }

  SearchResults searchResult = const SearchResults();
  final List<String> searchedTerms = [];
  List<String> searchHistoryResult = [];

  @override
  Future<SearchResults> search(String term) async {
    searchedTerms.add(term);
    return searchResult;
  }

  SearchSuggestions suggestionsResult = const SearchSuggestions();
  final List<String> suggestedTerms = [];

  @override
  Future<SearchSuggestions> searchSuggestions(String term) async {
    suggestedTerms.add(term);
    return suggestionsResult;
  }

  @override
  Future<List<String>> searchHistory() async => searchHistoryResult;

  @override
  Future<void> clearSearchHistory() async => searchHistoryResult = [];

  Event? rsvpToEventResult;
  ApiException? rsvpToEventError;
  EventAttendeeStatus? lastRsvpStatus;

  @override
  Future<Event> rsvpToEvent(int eventId, EventAttendeeStatus status) async {
    lastRsvpStatus = status;
    if (rsvpToEventError != null) throw rsvpToEventError!;
    return rsvpToEventResult!;
  }

  bool cancelEventRsvpCalled = false;

  @override
  Future<void> cancelEventRsvp(int eventId) async {
    cancelEventRsvpCalled = true;
  }

  Event? saveEventResult;
  ApiException? saveEventError;
  bool saveEventCalled = false;

  @override
  Future<Event> saveEvent(int eventId) async {
    saveEventCalled = true;
    if (saveEventError != null) throw saveEventError!;
    return saveEventResult!;
  }

  Event? unsaveEventResult;
  ApiException? unsaveEventError;
  bool unsaveEventCalled = false;

  @override
  Future<Event> unsaveEvent(int eventId) async {
    unsaveEventCalled = true;
    if (unsaveEventError != null) throw unsaveEventError!;
    return unsaveEventResult!;
  }

  String? lastRegisteredDeviceToken;
  String? lastUnregisteredDeviceToken;

  @override
  Future<void> registerDeviceToken(
    String token, {
    String platform = 'android',
  }) async {
    lastRegisteredDeviceToken = token;
  }

  @override
  Future<void> unregisterDeviceToken(String token) async {
    lastUnregisteredDeviceToken = token;
  }

  PaginatedResponse<AppNotification>? notificationsResult;
  ApiException? notificationsError;

  @override
  Future<PaginatedResponse<AppNotification>> notifications({
    int page = 1,
  }) async {
    if (notificationsError != null) throw notificationsError!;
    return notificationsResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  int unreadNotificationCountResult = 0;
  ApiException? unreadNotificationCountError;

  @override
  Future<int> unreadNotificationCount() async {
    if (unreadNotificationCountError != null)
      throw unreadNotificationCountError!;
    return unreadNotificationCountResult;
  }

  AppNotification? markNotificationReadResult;
  int? lastMarkedReadNotificationId;

  @override
  Future<AppNotification> markNotificationRead(int notificationId) async {
    lastMarkedReadNotificationId = notificationId;
    return markNotificationReadResult!;
  }

  bool markAllNotificationsReadCalled = false;

  @override
  Future<void> markAllNotificationsRead() async {
    markAllNotificationsReadCalled = true;
  }

  Post? postResult;
  ApiException? postError;

  @override
  Future<Post> post(int postId) async {
    if (postError != null) throw postError!;
    return postResult!;
  }

  SwapOffer? swapOfferResult;
  ApiException? swapOfferError;

  @override
  Future<SwapOffer> swapOffer(int swapOfferId) async {
    if (swapOfferError != null) throw swapOfferError!;
    return swapOfferResult!;
  }
}
