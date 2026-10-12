<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\NotificationType;
use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\NotificationService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\ValidationException;

/**
 * The follow graph — a one-way social signal ("see more from this grower"),
 * distinct from group membership (which is bidirectional and carries a
 * role) and from blocking (which is mutual and hides content both ways).
 * Following a blocked (or blocking) account is impossible, same guard as
 * UserController::show().
 */
class FollowController extends Controller
{
    private const PER_PAGE = 50;

    /**
     * Idempotent — following an already-followed user is a no-op and never
     * re-notifies them. Returns the followed user's own resource (with
     * refreshed counts and is_following=true) so the profile screen can
     * update in place, same pattern as PostController::like().
     */
    public function store(Request $request, User $user, NotificationService $notificationService): UserResource
    {
        $viewer = $request->user();

        if ($user->is($viewer)) {
            throw ValidationException::withMessages([
                'user' => ['You cannot follow yourself.'],
            ]);
        }

        abort_if($viewer->hasBlockRelationWith($user), 404);

        $isNewFollow = ! $viewer->following()->where('followed_id', $user->id)->exists();
        $viewer->following()->syncWithoutDetaching([
            $user->id => ['created_at' => now()],
        ]);

        if ($isNewFollow) {
            $notificationService->notify(
                $user,
                $viewer,
                NotificationType::UserFollowed,
                "{$viewer->name} started following you",
                'Tap to view their profile.',
                ['user_id' => $viewer->id],
            );
        }

        return $this->userWithFollowMeta($user, $viewer);
    }

    public function destroy(Request $request, User $user): UserResource
    {
        $viewer = $request->user();

        $viewer->following()->detach($user->id);

        return $this->userWithFollowMeta($user, $viewer);
    }

    /**
     * $user's followers, most recently followed first — reached from the
     * "Followers" count on their profile.
     */
    public function followers(Request $request, User $user): AnonymousResourceCollection
    {
        abort_if($request->user()->hasBlockRelationWith($user), 404);

        $followers = $user->followers()
            ->whereNotIn('users.id', $request->user()->hiddenUserIds())
            ->orderByPivot('created_at', 'desc')
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return UserResource::collection($followers);
    }

    /**
     * Growers $user follows, most recently followed first — reached from
     * the "Following" count on their profile.
     */
    public function following(Request $request, User $user): AnonymousResourceCollection
    {
        abort_if($request->user()->hasBlockRelationWith($user), 404);

        $following = $user->following()
            ->whereNotIn('users.id', $request->user()->hiddenUserIds())
            ->orderByPivot('created_at', 'desc')
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return UserResource::collection($following);
    }

    /**
     * Reloads $user's follow counts and whether $viewer currently follows
     * them, matching the correlated-subquery convention UserController::show()
     * uses for is_following on a single-resource response.
     */
    private function userWithFollowMeta(User $user, User $viewer): UserResource
    {
        $user->loadCount(['followers', 'following']);
        $user->setAttribute(
            'is_following',
            $viewer->following()->where('followed_id', $user->id)->exists(),
        );

        return new UserResource($user);
    }
}
