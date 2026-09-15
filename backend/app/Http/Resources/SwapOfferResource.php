<?php

namespace App\Http\Resources;

use App\Models\SwapOffer;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin SwapOffer
 */
class SwapOfferResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'status' => $this->status->value,
            'status_label' => $this->status->label(),
            'offer_details' => $this->offer_details,
            'unread_count' => $this->whenCounted('unread_count'),
            'listing' => new ListingResource($this->whenLoaded('listing')),
            'requester' => new UserResource($this->whenLoaded('requester')),
            'last_message' => $this->whenLoaded(
                'latestMessage',
                fn () => $this->latestMessage === null ? null : [
                    'body' => $this->latestMessage->body,
                    'has_image' => $this->latestMessage->image_path !== null,
                    'is_system_event' => $this->latestMessage->message_type->value === 'system_event',
                    'sender_id' => $this->latestMessage->sender_id,
                    'created_at' => $this->latestMessage->created_at?->toIso8601String(),
                ],
            ),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
