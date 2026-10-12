<?php

namespace App\Http\Resources;

use App\Models\GroupMessage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin GroupMessage
 */
class GroupMessageResource extends JsonResource
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
            // image_url is the first photo, kept for older app builds that only
            // show one; image_urls is every photo (empty for text-only).
            'image_url' => $this->resource->imageUrl(),
            'image_urls' => $this->resource->imageUrls(),
            // reply_to_id with a null reply_to means the quoted message was
            // deleted or is from a blocked user — show it as unavailable.
            'reply_to_id' => $this->reply_to_id,
            'reply_to' => $this->resource->relationLoaded('replyTo') ? $this->resource->replyPreview() : null,
            // [{emoji, count, user_ids}] — the app highlights the caller's own
            // from user_ids, so the same payload works over the broadcast.
            'reactions' => $this->resource->relationLoaded('reactions') ? $this->resource->reactionSummary() : [],
            // Null for a message whose original sender has since deleted
            // their account.
            'sender' => $this->sender_id !== null ? new UserResource($this->whenLoaded('sender')) : null,
            // Real group role at send time — set by the controller via
            // setAttribute() (see GroupMessageController) — not stored on the
            // message row itself, since group_members.role can change later.
            'sender_is_admin' => $this->when(
                array_key_exists('sender_is_admin', $this->resource->getAttributes()),
                fn () => (bool) $this->sender_is_admin,
            ),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
