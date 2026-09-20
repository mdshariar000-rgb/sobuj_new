<?php

use App\Http\Controllers\Api\V1\AiAssistantController;
use App\Http\Controllers\Api\V1\AuthController;
use App\Http\Controllers\Api\V1\BlockController;
use App\Http\Controllers\Api\V1\CommentController;
use App\Http\Controllers\Api\V1\ConfigController;
use App\Http\Controllers\Api\V1\DeviceTokenController;
use App\Http\Controllers\Api\V1\DiscoveryController;
use App\Http\Controllers\Api\V1\EventCategoryController;
use App\Http\Controllers\Api\V1\EventController;
use App\Http\Controllers\Api\V1\GroupCategoryController;
use App\Http\Controllers\Api\V1\GroupController;
use App\Http\Controllers\Api\V1\GroupJoinRequestController;
use App\Http\Controllers\Api\V1\GroupMessageController;
use App\Http\Controllers\Api\V1\HomeFeedController;
use App\Http\Controllers\Api\V1\ListingCategoryController;
use App\Http\Controllers\Api\V1\ListingController;
use App\Http\Controllers\Api\V1\MessageController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\PostCategoryController;
use App\Http\Controllers\Api\V1\PostController;
use App\Http\Controllers\Api\V1\ReportController;
use App\Http\Controllers\Api\V1\SubscriptionController;
use App\Http\Controllers\Api\V1\SwapOfferController;
use App\Http\Controllers\Api\V1\UserController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->group(function () {
    Route::post('/auth/register', [AuthController::class, 'register']);
    Route::post('/auth/login', [AuthController::class, 'login']);
    Route::get('/config/stripe-key', [ConfigController::class, 'stripeKey']);

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

            // Registered before the apiResource below so the literal "nearby"/"saved"
            // segments aren't swallowed by the "{listing}" wildcard route.
            Route::get('/listings/nearby', [DiscoveryController::class, 'nearby']);
            Route::get('/listings/saved', [ListingController::class, 'saved']);

            Route::apiResource('listings', ListingController::class);
            Route::post('/listings/{listing}/save', [ListingController::class, 'save']);
            Route::delete('/listings/{listing}/save', [ListingController::class, 'unsave']);

            Route::post('/listings/{listing}/swap-offers', [SwapOfferController::class, 'store']);
            Route::get('/swap-offers', [SwapOfferController::class, 'index']);
            Route::get('/swap-offers/{swapOffer}', [SwapOfferController::class, 'show']);
            Route::patch('/swap-offers/{swapOffer}/status', [SwapOfferController::class, 'updateStatus']);

            Route::get('/swap-offers/{swapOffer}/messages', [MessageController::class, 'index']);
            Route::post('/swap-offers/{swapOffer}/messages', [MessageController::class, 'store']);

            Route::get('/users/{user}', [UserController::class, 'show']);
            Route::get('/users/{user}/listings', [UserController::class, 'listings']);

            // Trust & safety — user-generated-content reporting and blocking
            Route::post('/reports', [ReportController::class, 'store']);
            Route::get('/blocks', [BlockController::class, 'index']);
            Route::post('/users/{user}/block', [BlockController::class, 'store']);
            Route::delete('/users/{user}/block', [BlockController::class, 'destroy']);

            // Agro Hub — Groups
            Route::get('/group-categories', [GroupCategoryController::class, 'index']);
            Route::get('/groups', [GroupController::class, 'index']);
            Route::post('/groups', [GroupController::class, 'store']);
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

            // Agro Hub — Home Feed, Posts & Comments
            Route::get('/feed', [HomeFeedController::class, 'index']);
            Route::get('/post-categories', [PostCategoryController::class, 'index']);
            Route::post('/posts', [PostController::class, 'store']);
            Route::get('/posts/{post}', [PostController::class, 'show']);
            Route::patch('/posts/{post}', [PostController::class, 'update']);
            Route::delete('/posts/{post}', [PostController::class, 'destroy']);
            Route::post('/posts/{post}/like', [PostController::class, 'like']);
            Route::delete('/posts/{post}/like', [PostController::class, 'unlike']);
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

            Route::get('/events/{event}', [EventController::class, 'show']);
            Route::patch('/events/{event}', [EventController::class, 'update']);
            Route::delete('/events/{event}', [EventController::class, 'destroy']);
            Route::post('/events/{event}/rsvp', [EventController::class, 'rsvp']);
            Route::delete('/events/{event}/rsvp', [EventController::class, 'cancelRsvp']);
            Route::post('/events/{event}/save', [EventController::class, 'save']);
            Route::delete('/events/{event}/save', [EventController::class, 'unsave']);

            // Agro Hub — Notifications
            // unread-count/read-all declared before the {notification} wildcard for
            // the same reason /listings/nearby is declared before /listings/{listing}.
            Route::get('/notifications', [NotificationController::class, 'index']);
            Route::get('/notifications/unread-count', [NotificationController::class, 'unreadCount']);
            Route::post('/notifications/read-all', [NotificationController::class, 'markAllRead']);
            Route::post('/notifications/{notification}/read', [NotificationController::class, 'markRead']);

            // Agro Hub — Agri-AI Assistant (subscription-gated — see AiConversationPolicy)
            Route::get('/ai/conversations', [AiAssistantController::class, 'index']);
            Route::get('/ai/conversations/{conversation}', [AiAssistantController::class, 'show']);
            Route::post('/ai/messages', [AiAssistantController::class, 'sendMessage']);

            // Agri-AI Premium subscription
            Route::get('/subscriptions/me', [SubscriptionController::class, 'show']);
            Route::post('/subscriptions', [SubscriptionController::class, 'store']);
            Route::delete('/subscriptions/me', [SubscriptionController::class, 'destroy']);
        });
    });
});
