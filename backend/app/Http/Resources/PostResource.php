<?php

namespace App\Http\Resources;

use App\Models\Post;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

/**
 * @mixin Post
 */
class PostResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'group_id' => $this->group_id,
            'body' => $this->body,
            'category' => $this->category,
            'approval_status' => $this->approval_status->value,
            'image_url' => $this->image_path !== null
                ? Storage::disk('public')->url($this->image_path)
                : null,
            'comments_count' => $this->whenCounted('comments'),
            // withCount(['likedBy as likes_count']) aliases the count column
            // directly to `likes_count`, so whenCounted('likedBy') (which
            // looks for `liked_by_count`) wouldn't find it — check the real
            // attribute name instead, same pattern as liked_by_me below.
            'likes_count' => $this->when(
                array_key_exists('likes_count', $this->resource->getAttributes()),
                fn () => (int) $this->likes_count,
            ),
            'liked_by_me' => $this->when(
                array_key_exists('liked_by_me', $this->resource->getAttributes()),
                fn () => (bool) $this->liked_by_me,
            ),
            'author' => new UserResource($this->whenLoaded('author')),
            'group' => new GroupResource($this->whenLoaded('group')),
            'comments' => CommentResource::collection($this->whenLoaded('comments')),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
