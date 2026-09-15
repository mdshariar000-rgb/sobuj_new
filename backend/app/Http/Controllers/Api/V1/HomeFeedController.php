<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\PostModerationStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\PostResource;
use App\Models\Post;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class HomeFeedController extends Controller
{
    private const PER_PAGE = 20;

    /**
     * The general community Home Feed — posts with no group_id, newest first.
     * ?search= matches against the post body or its author's name (same
     * `when()`-guarded LIKE pattern as GroupController::index()).
     * ?author_id= narrows to one author's posts — "My Posts" on their profile.
     * ?category= narrows to one admin-managed post category name (see
     * PostCategory) — backs the Home tab's Recent/Disease Alerts/Harvests
     * chips; omitted (the "Recent" chip) shows every category, newest first.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate([
            'category' => ['nullable', 'string', Rule::exists('post_categories', 'name')],
        ]);

        $posts = Post::query()
            ->generalFeed()
            ->where('moderation_status', PostModerationStatus::Visible)
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = '%'.$request->string('search').'%';
                $query->where(function ($query) use ($term) {
                    $query->where('body', 'like', $term)
                        ->orWhereHas('author', fn ($query) => $query->where('name', 'like', $term));
                });
            })
            ->when(
                $request->filled('author_id'),
                fn ($query) => $query->where('author_id', $request->integer('author_id')),
            )
            ->when(
                $request->filled('category'),
                fn ($query) => $query->where('category', $request->string('category')),
            )
            ->withCount(['comments', 'likedBy as likes_count'])
            // Cheap correlated-subquery column rather than eager-loading every
            // post's full like list — same pattern as EventController::index()'s
            // my_rsvp_status.
            ->addSelect(['liked_by_me' => DB::table('post_likes')
                ->selectRaw('1')
                ->whereColumn('post_id', 'posts.id')
                ->where('user_id', $request->user()->id)
                ->limit(1),
            ])
            ->with('author')
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return PostResource::collection($posts);
    }
}
