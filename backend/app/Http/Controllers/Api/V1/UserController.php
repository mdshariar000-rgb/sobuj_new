<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\GroupStatus;
use App\Enums\GroupVisibility;
use App\Enums\ListingStatus;
use App\Enums\PostApprovalStatus;
use App\Enums\PostModerationStatus;
use App\Enums\SwapOfferStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\ListingResource;
use App\Http\Resources\PostResource;
use App\Http\Resources\UserResource;
use App\Models\Group;
use App\Models\ListingReview;
use App\Models\Post;
use App\Models\SwapOffer;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

/**
 * A grower's public profile — reached from "View Seller Profile" on a
 * listing card. Only ever exposes what UserResource already treats as
 * public (name, verification, growing setup/experience, rating) plus their
 * active listings; never email/suspension state.
 */
class UserController extends Controller
{
    private const PER_PAGE = 20;

    /**
     * How far "near you" reaches when suggesting growers to follow.
     */
    private const SUGGEST_RADIUS_METERS = 100_000;

    private const SUGGEST_LIMIT = 20;

    /**
     * GET /users/suggested — growers to follow during onboarding: the nearest
     * ones to the viewer's registered location first, topped up with the
     * most active growers anywhere. Never the viewer, anyone already
     * followed, blocked either way, or suspended.
     */
    public function suggested(Request $request): AnonymousResourceCollection
    {
        $viewer = $request->user();

        $base = fn () => User::query()
            ->whereKeyNot($viewer->id)
            ->whereNotIn('users.id', $viewer->hiddenUserIds())
            ->whereNotIn('users.id', $viewer->following()->select('users.id'))
            ->where('is_suspended', false)
            ->withCount('posts');

        $coordinates = $viewer->getExactCoordinates();
        $nearby = $coordinates === null
            ? collect()
            : $base()
                ->nearby($coordinates['latitude'], $coordinates['longitude'], self::SUGGEST_RADIUS_METERS)
                ->limit(self::SUGGEST_LIMIT)
                ->get();

        $active = $nearby->count() >= self::SUGGEST_LIMIT
            ? collect()
            : $base()
                ->whereNotIn('users.id', $nearby->pluck('id')->all())
                ->orderByDesc('posts_count')
                ->latest()
                ->limit(self::SUGGEST_LIMIT - $nearby->count())
                ->get();

        return UserResource::collection($nearby->concat($active));
    }

    public function show(Request $request, User $user): UserResource
    {
        abort_if($request->user()->hasBlockRelationWith($user), 404);

        $user->loadCount([
            'followers',
            'following',
            // What their profile's Posts tab actually lists — see posts().
            'posts' => fn ($query) => $query
                ->whereIn('group_id', $this->visibleGroupIds($request->user(), $user))
                ->where('moderation_status', PostModerationStatus::Visible)
                ->when(! $request->user()->is($user), fn ($query) => $query
                    ->where('approval_status', PostApprovalStatus::Approved)),
            'listings as active_listings_count' => fn ($query) => $query->where('status', ListingStatus::Active),
        ]);
        $user->setAttribute(
            'is_following',
            $request->user()->following()->where('followed_id', $user->id)->exists(),
        );

        // Trust signals: how buyers rated their listings (only buyers with a
        // completed deal can review — see ListingReviewController::store()),
        // and how many deals they've completed on either side.
        $reviews = ListingReview::query()
            ->whereHas('listing', fn ($query) => $query->where('user_id', $user->id))
            ->whereNotIn('reviewer_id', $request->user()->hiddenUserIds())
            ->selectRaw('COUNT(*) as reviews_count, AVG(rating) as average_rating')
            ->first();
        $user->setAttribute('seller_reviews_count', (int) $reviews->reviews_count);
        $user->setAttribute(
            'seller_rating',
            $reviews->average_rating !== null ? round((float) $reviews->average_rating, 1) : null,
        );
        $user->setAttribute('completed_deals_count', SwapOffer::query()
            ->where('status', SwapOfferStatus::Completed)
            ->where(fn ($query) => $query
                ->where('requester_id', $user->id)
                ->orWhereHas('listing', fn ($query) => $query->where('user_id', $user->id)))
            ->count());

        return new UserResource($user);
    }

    public function listings(Request $request, User $user): AnonymousResourceCollection
    {
        abort_if($request->user()->hasBlockRelationWith($user), 404);

        $listings = $user->listings()
            ->where('status', ListingStatus::Active)
            ->selectFuzzyCoordinates()
            ->with('photos')
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return ListingResource::collection($listings);
    }

    /**
     * GET /users/{user}/posts — a profile's posts ("My Posts"). Posts only
     * live in groups, so these are the user's posts in groups the viewer can
     * see: active, and public or one the viewer is in. On your own profile,
     * every active group you posted in, including posts still awaiting a
     * private group's approval (marked pending).
     */
    public function posts(Request $request, User $user): AnonymousResourceCollection
    {
        $viewer = $request->user();
        abort_if($viewer->hasBlockRelationWith($user), 404);
        $ownProfile = $viewer->is($user);

        $visibleGroupIds = $this->visibleGroupIds($viewer, $user);

        $posts = Post::query()
            ->where('author_id', $user->id)
            ->whereIn('group_id', $visibleGroupIds)
            ->where('moderation_status', PostModerationStatus::Visible)
            ->when(! $ownProfile, fn ($query) => $query->where('approval_status', PostApprovalStatus::Approved))
            ->withCount(Post::RESOURCE_COUNTS)
            ->addSelect(['liked_by_me' => DB::table('post_likes')
                ->selectRaw('1')
                ->whereColumn('post_id', 'posts.id')
                ->where('user_id', $viewer->id)
                ->limit(1),
            ])
            ->with(Post::RESOURCE_RELATIONS)
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return PostResource::collection($posts);
    }

    /**
     * Groups whose posts $viewer may see on $owner's profile: active, and
     * public or one the viewer is in — every active group on your own.
     */
    private function visibleGroupIds(User $viewer, User $owner): Builder
    {
        return Group::query()
            ->where('status', GroupStatus::Active)
            ->when(! $viewer->is($owner), fn ($query) => $query->where(fn ($query) => $query
                ->where('visibility', GroupVisibility::Public)
                ->orWhereIn('id', $viewer->groups()->select('groups.id'))))
            ->select('id');
    }
}
