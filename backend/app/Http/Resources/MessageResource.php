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
            'image_url' => $this->resource->imageUrl(),
            // Null for system_event messages, which have no acting sender.
            'sender' => $this->sender_id !== null ? new UserResource($this->whenLoaded('sender')) : null,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
