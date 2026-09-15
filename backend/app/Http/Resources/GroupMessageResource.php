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
            'image_url' => $this->resource->imageUrl(),
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
