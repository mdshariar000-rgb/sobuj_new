<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\GroupMemberRole;
use App\Enums\GroupStatus;
use App\Enums\PostApprovalStatus;
use App\Enums\PostModerationStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Post\StorePostRequest;
use App\Http\Resources\PostResource;
use App\Models\Group;
use App\Models\Post;
use App\Services\ImageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class PostController extends Controller
{
    private const PER_PAGE = 20;

    /**
     * Adds comments_count/likes_count and, for the authenticated user,
     * liked_by_me — a cheap correlated-subquery column (see
     * EventController::index()'s my_rsvp_status for the same pattern)
     * rather than eager-loading every post's full like list.
     *
     * Untyped/no return type: called with both a plain Builder (Post::query())
     * and a HasMany relation query ($group->posts()) — both support the same
     * fluent methods, but HasMany isn't a Builder subclass.
     */
    private function withPostMeta($query, Request $request)
    {
        return $query
            ->withCount(['comments', 'likedBy as likes_count'])
            ->addSelect(['liked_by_me' => DB::table('post_likes')
                ->selectRaw('1')
                ->whereColumn('post_id', 'posts.id')
                ->where('user_id', $request->user()->id)
                ->limit(1),
            ]);
    }

    /**
     * A single group's discussion-thread posts. The general Home Feed is served
     * separately by HomeFeedController.
     *
     * A pending/rejected post (only possible in a private group — see
     * store()) is invisible to everyone except its own author and that
     * group's admins, who see every post regardless of status so they can
     * moderate it.
     */
    public function index(Group $group, Request $request): AnonymousResourceCollection
    {
        abort_if($group->status !== GroupStatus::Active, 403, 'This group is no longer available.');

        $isGroupAdmin = $group->members()
            ->where('user_id', $request->user()->id)
            ->wherePivot('role', GroupMemberRole::Admin)
            ->exists();

        $posts = $this->withPostMeta($group->posts(), $request)
            // Site-wide admin takedown always wins over group-level approval
            // state — a banned/deactivated post stays hidden even from the
            // group's own admin.
            ->where('moderation_status', PostModerationStatus::Visible)
            ->when(! $isGroupAdmin, fn ($query) => $query->where(function ($query) use ($request) {
                $query->where('approval_status', PostApprovalStatus::Approved)
                    ->orWhere('author_id', $request->user()->id);
            }))
            ->with('author')
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return PostResource::collection($posts);
    }

    /**
     * Posts to the general Home Feed when group_id is omitted, or into a
     * group's discussion thread when it's set — group membership is required
     * for the latter. A non-admin member's post into a *private* group
     * starts approval_status pending rather than immediately visible to the
     * rest of the group — see index()/PostPolicy::view(). Every other case
     * (Home Feed, public group, or the group's own admin posting) is
     * approved immediately, same as before this feature existed.
     */
    public function store(StorePostRequest $request, ImageService $imageService): JsonResponse
    {
        $data = $request->validated();
        $user = $request->user();
        $approvalStatus = PostApprovalStatus::Approved;

        if (! empty($data['group_id'])) {
            $group = Group::query()->findOrFail($data['group_id']);
            abort_if($group->status !== GroupStatus::Active, 403, 'This group is no longer available.');
            $membership = $group->members()->where('user_id', $user->id)->first();

            if ($membership === null) {
                throw ValidationException::withMessages([
                    'group_id' => ['You must be a member of this group to post in it.'],
                ]);
            }

            if ($group->isPrivate() && $membership->pivot->role !== GroupMemberRole::Admin) {
                $approvalStatus = PostApprovalStatus::Pending;
            }
        }

        $post = new Post([
            'group_id' => $data['group_id'] ?? null,
            'body' => $data['body'],
            'category' => $data['category'] ?? 'General',
        ]);
        $post->author_id = $user->id;
        $post->approval_status = $approvalStatus;

        if ($request->hasFile('image')) {
            $post->image_path = $imageService->store($request->file('image'), 'posts');
        }

        $post->save();

        $freshPost = $post->fresh(['author', 'group']);
        $freshPost->loadCount(['comments', 'likedBy as likes_count']);
        // A post the author just created can't already be liked.
        $freshPost->setAttribute('liked_by_me', false);

        return (new PostResource($freshPost))
            ->response()
            ->setStatusCode(201);
    }

    public function show(Request $request, Post $post): PostResource
    {
        $this->authorize('view', $post);

        $post->loadCount(['comments', 'likedBy as likes_count'])
            ->loadMissing(['author', 'group', 'comments.author']);
        $post->setAttribute(
            'liked_by_me',
            $post->likedBy()->where('user_id', $request->user()->id)->exists(),
        );

        return new PostResource($post);
    }

    public function destroy(Post $post): JsonResponse
    {
        $this->authorize('delete', $post);

        $post->delete();

        return response()->json(['message' => 'Post deleted.']);
    }

    /**
     * The post's group admin/creator approves a pending (or previously
     * rejected) post, making it visible to the rest of the group.
     */
    public function approve(Post $post): JsonResponse
    {
        $this->authorize('moderate', $post);

        // approval_status isn't mass-assignable (see Post::$fillable), so
        // update() would silently drop it — set it directly instead.
        $post->approval_status = PostApprovalStatus::Approved;
        $post->save();

        return response()->json(['message' => 'Post approved.']);
    }

    /**
     * The post's group admin/creator rejects it — it stays in the database
     * (real moderation history) but only the author and admins can see it.
     */
    public function reject(Post $post): JsonResponse
    {
        $this->authorize('moderate', $post);

        $post->approval_status = PostApprovalStatus::Rejected;
        $post->save();

        return response()->json(['message' => 'Post rejected.']);
    }

    public function like(Request $request, Post $post): PostResource
    {
        $post->likedBy()->syncWithoutDetaching([$request->user()->id]);

        $post->loadCount(['comments', 'likedBy as likes_count'])
            ->loadMissing(['author', 'group']);
        $post->setAttribute('liked_by_me', true);

        return new PostResource($post);
    }

    public function unlike(Request $request, Post $post): PostResource
    {
        $post->likedBy()->detach($request->user()->id);

        $post->loadCount(['comments', 'likedBy as likes_count'])
            ->loadMissing(['author', 'group']);
        $post->setAttribute('liked_by_me', false);

        return new PostResource($post);
    }
}
