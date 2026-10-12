<?php

namespace App\Http\Resources;

use App\Models\Message;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Message
 */
class MessageResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'swap_offer_id' => $this->swap_offer_id,
            'message_type' => $this->message_type->value,
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
            // Null for system_event messages, which have no acting sender.
            'sender' => $this->sender_id !== null ? new UserResource($this->whenLoaded('sender')) : null,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
