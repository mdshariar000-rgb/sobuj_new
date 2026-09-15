<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A user in the context of one group's membership — their real pivot role
 * and join date, alongside their public profile fields.
 *
 * @mixin User
 */
class GroupMemberResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'username' => $this->username,
            'avatar_url' => $this->resource->avatarUrl(),
            'is_verified' => $this->verified_at !== null,
            'experience_level' => $this->experience_level?->value,
            'growing_setup' => $this->growing_setup?->value,
            'role' => $this->pivot->role->value,
            'joined_at' => $this->pivot->joined_at?->toIso8601String(),
        ];
    }
}
