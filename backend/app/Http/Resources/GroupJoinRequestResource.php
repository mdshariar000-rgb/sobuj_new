<?php

namespace App\Http\Resources;

use App\Models\GroupJoinRequest;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin GroupJoinRequest
 */
class GroupJoinRequestResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'user' => new UserResource($this->whenLoaded('user')),
            'requested_at' => $this->requested_at?->toIso8601String(),
        ];
    }
}
