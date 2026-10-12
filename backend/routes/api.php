<?php

use App\Http\Controllers\Api\V1\AddressController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BlockController;
use App\Http\Controllers\Api\V1\CommentController;
use App\Http\Controllers\Api\V1\DeviceTokenController;
use App\Http\Controllers\Api\V1\DiscoveryController;
use App\Http\Controllers\Api\V1\EventCategoryController;
use App\Http\Controllers\Api\V1\EventController;
use App\Http\Controllers\Api\V1\EventReviewController;
use App\Http\Controllers\Api\V1\FeedMarketplaceController;
use App\Http\Controllers\Api\V1\FollowController;
use App\Http\Controllers\Api\V1\GroupCategoryController;
use App\Http\Controllers\Api\V1\GroupController;
use App\Http\Controllers\Api\V1\GroupJoinRequestController;
use App\Http\Controllers\Api\V1\GroupMessageController;
use App\Http\Controllers\Api\V1\GroupRequestController;
use App\Http\Controllers\Api\V1\ListingCategoryController;
use App\Http\Controllers\Api\V1\ListingController;
use App\Http\Controllers\Api\V1\ListingReviewController;
use App\Http\Controllers\Api\V1\MessageController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\PasswordResetController;
use App\Http\Controllers\Api\V1\PostController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\RetiredFeatureController;
use App\Http\Controllers\Api\V1\SearchController;
use App\Http\Controllers\Api\V1\SocialConfigController;
use App\Http\Controllers\Api\V1\SowingGuideController;
use App\Http\Controllers\Api\V1\SwapOfferController;
use App\Http\Controllers\Api\V1\UserController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('/auth/register', [AuthController::class, 'register']);
    Route::post('/auth/login', [AuthController::class, 'login']);
    Route::post('/auth/social', [AuthController::class, 'social'])->middleware('throttle:20,1');
    Route::get('/config/social', SocialConfigController::class);
    // Address suggestions for sign-up — public, so rate limited per IP.
    Route::get('/addresses/suggest', [AddressController::class, 'suggest'])->middleware('throttle:60,1');
    // Paid per lookup, so a tighter limit.
    Route::get('/addresses/postcode', [AddressController::class, 'postcode'])->middleware('throttle:20,1');
    Route::post('/auth/forgot-password', [PasswordResetController::class, 'sendCode'])->middleware('throttle:5,1');
    Route::post('/auth/reset-password', [PasswordResetController::class, 'reset'])->middleware('throttle:10,1');
    // Retired (Agri-AI Premium) — see RetiredFeatureController.
    Route::get('/config/stripe-key', RetiredFeatureController::class);

    Route::middleware('auth:sanctum')->group(function () {
        // Always available on a valid token, even a suspended account's — the app
        // needs /me to detect "you're suspended" and logout to always be able to
        // sign out, regardless of account standing.
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::delete('/auth/me', [AuthController::class, 'destroy']);

        // Tied to the login/logout lifecycle exactly like the two routes
        // above — a suspended account should still be able to unregister
        // its device on logout, even though it can't use the rest of the API.
        Route::post('/device-tokens', [DeviceTokenController::class, 'store']);
        Route::delete('/device-tokens', [DeviceTokenController::class, 'destroy']);

        Route::middleware('not_suspended')->group(function () {
            Route::patch('/auth/me', [AuthController::class, 'updateProfile']);

            Route::get('/listing-categories', [ListingCategoryController::class, 'index']);
            Route::get('/sowing-guide', [SowingGuideController::class, 'index']);

            // Registered before the apiResource below so the literal "nearby"/"saved"
            // segments aren't swallowed by the "{listing}" wildcard route.
            Route::get('/listings/nearby', [DiscoveryController::class, 'nearby']);
            Route::get('/listings/saved', [ListingController::class, 'saved']);

            Route::apiResource('listings', ListingController::class);
            Route::post('/listings/{listing}/save', [ListingController::class, 'save']);
            Route::delete('/listings/{listing}/save', [ListingController::class, 'unsave']);

            // Star rating + comment on a listing — see ListingReviewController.
            Route::get('/listings/{listing}/reviews', [ListingReviewController::class, 'index']);
            Route::post('/listings/{listing}/reviews', [ListingReviewController::class, 'store']);
            Route::delete('/listings/{listing}/reviews/{review}', [ListingReviewController::class, 'destroy']);

            Route::post('/listings/{listing}/swap-offers', [SwapOfferController::class, 'store']);
            Route::get('/swap-offers', [SwapOfferController::class, 'index']);
            Route::get('/swap-offers/{swapOffer}', [SwapOfferController::class, 'show']);
            Route::patch('/swap-offers/{swapOffer}/status', [SwapOfferController::class, 'updateStatus']);

            Route::get('/swap-offers/{swapOffer}/messages', [MessageController::class, 'index']);
            Route::post('/swap-offers/{swapOffer}/messages', [MessageController::class, 'store']);
            Route::put('/swap-offers/{swapOffer}/messages/{message}/reaction', [MessageController::class, 'react']);
            Route::delete('/swap-offers/{swapOffer}/messages/{message}/reaction', [MessageController::class, 'unreact']);

            // Before /users/{user}, so "suggested" isn't taken as a user id.
            Route::get('/users/suggested', [UserController::class, 'suggested']);
            Route::get('/users/{user}', [UserController::class, 'show']);
            Route::get('/users/{user}/listings', [UserController::class, 'listings']);
            Route::get('/users/{user}/posts', [UserController::class, 'posts']);

            // Follow graph — a one-way social signal, distinct from group
            // membership (bidirectional, has a role) and blocking (mutual,
            // hides content both ways). See FollowController.
            Route::post('/users/{user}/follow', [FollowController::class, 'store']);
            Route::delete('/users/{user}/follow', [FollowController::class, 'destroy']);
            Route::get('/users/{user}/followers', [FollowController::class, 'followers']);
            Route::get('/users/{user}/following', [FollowController::class, 'following']);

            // Trust & safety — user-generated-content reporting and blocking
            Route::post('/reports', [ReportController::class, 'store']);
            Route::get('/blocks', [BlockController::class, 'index']);
            Route::post('/users/{user}/block', [BlockController::class, 'store']);
            Route::delete('/users/{user}/block', [BlockController::class, 'destroy']);

            // Agro Hub — Groups
            Route::get('/group-categories', [GroupCategoryController::class, 'index']);
            Route::get('/groups', [GroupController::class, 'index']);
            Route::get('/groups/suggested', [GroupController::class, 'suggested']);
            Route::post('/groups', [GroupController::class, 'store']);
            Route::post('/group-requests', [GroupRequestController::class, 'store']);
            Route::get('/groups/{group}', [GroupController::class, 'show']);
            Route::patch('/groups/{group}', [GroupController::class, 'update']);
            Route::delete('/groups/{group}', [GroupController::class, 'destroy']);
            Route::post('/groups/{group}/join', [GroupController::class, 'join']);
            Route::delete('/groups/{group}/join-requests/me', [GroupController::class, 'cancelJoinRequest']);
            Route::get('/groups/{group}/join-requests', [GroupJoinRequestController::class, 'index']);
            Route::patch('/groups/{group}/join-requests/{joinRequest}', [GroupJoinRequestController::class, 'update']);
            Route::post('/groups/{group}/leave', [GroupController::class, 'leave']);
            Route::get('/groups/{group}/posts', [PostController::class, 'index']);
            Route::get('/groups/{group}/members', [GroupController::class, 'members']);
            Route::get('/groups/{group}/messages', [GroupMessageController::class, 'index']);
            Route::post('/groups/{group}/messages', [GroupMessageController::class, 'store']);
            Route::put('/groups/{group}/messages/{groupMessage}/reaction', [GroupMessageController::class, 'react']);
            Route::delete('/groups/{group}/messages/{groupMessage}/reaction', [GroupMessageController::class, 'unreact']);

            // Agro Hub — Home Feed, Posts & Comments
            // Retired: the personal Home timeline — see RetiredFeatureController.
            Route::get('/feed', RetiredFeatureController::class);
            Route::get('/feed/marketplace', [FeedMarketplaceController::class, 'index']);
            Route::get('/search', [SearchController::class, 'search']);
            Route::get('/search/suggest', [SearchController::class, 'suggest']);
            Route::get('/search/history', [SearchController::class, 'history']);
            Route::delete('/search/history', [SearchController::class, 'clearHistory']);
            Route::get('/post-categories', RetiredFeatureController::class);
            Route::post('/posts', [PostController::class, 'store']);
            Route::get('/posts/{post}', [PostController::class, 'show']);
            Route::patch('/posts/{post}', [PostController::class, 'update']);
            Route::delete('/posts/{post}', [PostController::class, 'destroy']);
            Route::post('/posts/{post}/like', [PostController::class, 'like']);
            Route::delete('/posts/{post}/like', [PostController::class, 'unlike']);
            Route::post('/posts/{post}/share', RetiredFeatureController::class);
            Route::post('/posts/{post}/approve', [PostController::class, 'approve']);
            Route::post('/posts/{post}/reject', [PostController::class, 'reject']);
            Route::get('/posts/{post}/comments', [CommentController::class, 'index']);
            Route::post('/posts/{post}/comments', [CommentController::class, 'store']);
            Route::delete('/comments/{comment}', [CommentController::class, 'destroy']);

            // Agro Hub — Events & Workshops
            Route::get('/event-categories', [EventCategoryController::class, 'index']);
            Route::get('/events', [EventController::class, 'index']);
            Route::post('/events', [EventController::class, 'store']);

            // Registered before the "{event}" wildcard below so the literal
            // "saved" segment isn't swallowed by it — same reasoning as
            // /listings/nearby vs /listings/{listing}.
            Route::get('/events/saved', [EventController::class, 'saved']);
            Route::get('/events/mine', [EventController::class, 'mine']);

            Route::get('/events/{event}', [EventController::class, 'show']);
            Route::patch('/events/{event}', [EventController::class, 'update']);
            Route::delete('/events/{event}', [EventController::class, 'destroy']);
            Route::post('/events/{event}/rsvp', [EventController::class, 'rsvp']);
            Route::delete('/events/{event}/rsvp', [EventController::class, 'cancelRsvp']);
            Route::get('/events/{event}/chat', [EventController::class, 'chat']);
            Route::post('/events/{event}/save', [EventController::class, 'save']);
            Route::delete('/events/{event}/save', [EventController::class, 'unsave']);
            Route::get('/events/{event}/reviews', [EventReviewController::class, 'index']);
            Route::post('/events/{event}/reviews', [EventReviewController::class, 'store']);
            Route::delete('/events/{event}/reviews/{review}', [EventReviewController::class, 'destroy']);

            // Agro Hub — Notifications
            // unread-count/read-all declared before the {notification} wildcard for
            // the same reason /listings/nearby is declared before /listings/{listing}.
            Route::get('/notifications', [NotificationController::class, 'index']);
            Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount']);
            Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead']);
            Route::post('/notifications/{notification}/read', [NotificationController::class, 'markRead']);

            // Retired (Agri-AI assistant + Premium subscription) — older app
            // builds still call these, so they get a 410 with a readable message.
            Route::get('/ai/conversations', RetiredFeatureController::class);
            Route::get('/ai/conversations/{conversation}', RetiredFeatureController::class);
            Route::post('/ai/messages', RetiredFeatureController::class);
            Route::get('/subscriptions/me', RetiredFeatureController::class);
            Route::post('/subscriptions', RetiredFeatureController::class);
            Route::delete('/subscriptions/me', RetiredFeatureController::class);
        });
    });
});
