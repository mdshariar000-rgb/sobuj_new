import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shobuj_mobile/models/agri_ai_config.dart';
import 'package:shobuj_mobile/models/app_user.dart';
import 'package:shobuj_mobile/models/ai_conversation.dart';
import 'package:shobuj_mobile/models/comment.dart';
import 'package:shobuj_mobile/models/enums.dart';
import 'package:shobuj_mobile/models/event.dart';
import 'package:shobuj_mobile/models/event_category.dart';
import 'package:shobuj_mobile/models/event_enums.dart';
import 'package:shobuj_mobile/models/group.dart';
import 'package:shobuj_mobile/models/group_category.dart';
import 'package:shobuj_mobile/models/group_join_request.dart';
import 'package:shobuj_mobile/models/group_member.dart';
import 'package:shobuj_mobile/models/group_message.dart';
import 'package:shobuj_mobile/models/listing.dart';
import 'package:shobuj_mobile/models/paginated_response.dart';
import 'package:shobuj_mobile/models/post.dart';
import 'package:shobuj_mobile/models/post_category.dart';
import 'package:shobuj_mobile/models/subscription_status.dart';
import 'package:shobuj_mobile/models/swap_message.dart';
import 'package:shobuj_mobile/models/swap_offer.dart';
import 'package:shobuj_mobile/services/api_client.dart';
import 'package:shobuj_mobile/services/api_exception.dart';

AppUser buildFakeUser({
  int id = 1,
  String name = 'Rina',
  String email = 'rina@example.com',
}) {
  return AppUser(
    id: id,
    name: name,
    email: email,
    isSuspended: false,
    suspensionReason: null,
    isVerified: false,
    ratingAvg: 0,
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
    String? experienceLevel,
    String? growingSetup,
  }) async {
    if (registerError != null) throw registerError!;
    return registerResult!;
  }

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }

  /// Defaults to an empty result so tests that land on the Discovery screen
  /// as a side effect (e.g. after login) don't trip a real network call —
  /// override per-test when a case actually needs to assert on listings.
  @override
  Future<PaginatedResponse<Listing>> nearbyListings({
    required double latitude,
    required double longitude,
    double radiusKm = 10,
    ListingType? category,
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
  }) async {
    lastUpdateProfileArgs = {
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

  PaginatedResponse<Post>? homeFeedResult;
  ApiException? homeFeedError;
  String? lastHomeFeedSearch;
  String? lastHomeFeedCategory;

  /// Defaults to an empty result for the same reason as [nearbyListings] —
  /// the Home Feed is the default tab after login, so most tests that land
  /// there as a side effect shouldn't trip a real network call.
  @override
  Future<PaginatedResponse<Post>> homeFeed({
    String? search,
    int? authorId,
    String? category,
    int page = 1,
  }) async {
    lastHomeFeedSearch = search;
    lastHomeFeedCategory = category;
    if (homeFeedError != null) throw homeFeedError!;
    return homeFeedResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  Post? createPostResult;
  ApiException? createPostError;
  String? lastCreatePostCategory;

  @override
  Future<Post> createPost({
    required String body,
    int? groupId,
    String? category,
    File? image,
  }) async {
    lastCreatePostCategory = category;
    if (createPostError != null) throw createPostError!;
    return createPostResult!;
  }

  List<PostCategory>? postCategoriesResult;
  ApiException? postCategoriesError;

  /// Defaults to the app's real seeded list (General/Disease Alert/Harvest)
  /// so tests that touch the Home Feed or composer without caring about
  /// categories specifically still see realistic chips/options.
  @override
  Future<List<PostCategory>> postCategories() async {
    if (postCategoriesError != null) throw postCategoriesError!;
    return postCategoriesResult ??
        const [
          PostCategory(id: 1, name: 'General'),
          PostCategory(id: 2, name: 'Disease Alert'),
          PostCategory(id: 3, name: 'Harvest'),
        ];
  }

  bool deletePostCalled = false;

  @override
  Future<void> deletePost(int postId) async {
    deletePostCalled = true;
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
    int page = 1,
  }) async {
    lastGroupsCallArgs = {'search': search, 'category': category, 'page': page};
    if (groupsError != null) throw groupsError!;
    return groupsResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
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

  @override
  Future<GroupMessage> sendGroupMessage(
    int groupId, {
    String? body,
    File? image,
  }) async {
    lastSentGroupMessageBody = body;
    if (sendGroupMessageError != null) throw sendGroupMessageError!;
    return sendGroupMessageResult!;
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

  @override
  Future<SwapMessage> sendSwapOfferMessage(
    int swapOfferId, {
    String? body,
    File? image,
  }) async {
    lastSentSwapOfferMessageBody = body;
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

  PaginatedResponse<AiConversation>? aiConversationsResult;
  ApiException? aiConversationsError;

  @override
  Future<PaginatedResponse<AiConversation>> aiConversations({
    int page = 1,
  }) async {
    if (aiConversationsError != null) throw aiConversationsError!;
    return aiConversationsResult ??
        const PaginatedResponse(
          data: [],
          currentPage: 1,
          lastPage: 1,
          total: 0,
        );
  }

  AiConversation? aiConversationResult;
  ApiException? aiConversationError;

  @override
  Future<AiConversation> aiConversation(int conversationId) async {
    if (aiConversationError != null) throw aiConversationError!;
    return aiConversationResult!;
  }

  AiConversation? sendAiMessageResult;
  ApiException? sendAiMessageError;
  int? lastSendAiMessageConversationId;

  @override
  Future<AiConversation> sendAiMessage({
    int? conversationId,
    String? body,
    File? photo,
  }) async {
    lastSendAiMessageConversationId = conversationId;
    if (sendAiMessageError != null) throw sendAiMessageError!;
    return sendAiMessageResult!;
  }

  SubscriptionStatus? subscriptionStatusResult;
  ApiException? subscriptionStatusError;

  /// Defaults to "subscribed" — like [aiConversations], the Agri-AI tab is
  /// reachable by default in tests that aren't specifically about the
  /// paywall; override with an explicit `hasAccess: false` result to test
  /// the gate itself.
  @override
  Future<SubscriptionStatus> subscriptionStatus() async {
    if (subscriptionStatusError != null) throw subscriptionStatusError!;
    return subscriptionStatusResult ??
        const SubscriptionStatus(
          hasAccess: true,
          plan: 'monthly',
          status: 'active',
          onTrial: false,
          cancelAtPeriodEnd: false,
        );
  }

  AgriAiConfig agriAiConfigResult = const AgriAiConfig(
    publishableKey: 'pk_test_fake',
    monthlyPriceUsd: 9.99,
    annualPriceUsd: 71.88,
  );

  @override
  Future<AgriAiConfig> agriAiConfig() async => agriAiConfigResult;

  SubscribeResult? createSubscriptionResult;
  ApiException? createSubscriptionError;
  String? lastSubscribePlan;
  String? lastSubscribePaymentMethodId;

  @override
  Future<SubscribeResult> createSubscription({
    required String plan,
    required String paymentMethodId,
  }) async {
    lastSubscribePlan = plan;
    lastSubscribePaymentMethodId = paymentMethodId;
    if (createSubscriptionError != null) throw createSubscriptionError!;
    return createSubscriptionResult!;
  }

  SubscriptionStatus? cancelSubscriptionResult;
  ApiException? cancelSubscriptionError;
  bool cancelSubscriptionCalled = false;

  @override
  Future<SubscriptionStatus> cancelSubscription() async {
    cancelSubscriptionCalled = true;
    if (cancelSubscriptionError != null) throw cancelSubscriptionError!;
    return cancelSubscriptionResult!;
  }

  PaginatedResponse<Event>? eventsResult;
  ApiException? eventsError;
  String? lastEventsMonth;
  String? lastEventsCategory;

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
    int page = 1,
  }) async {
    lastEventsMonth = month;
    lastEventsCategory = category;
    if (eventsError != null) throw eventsError!;
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
    required EventStatus status,
  }) async {
    if (createEventError != null) throw createEventError!;
    return createEventResult!;
  }

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
}
