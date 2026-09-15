<?php

namespace App\Http\Resources;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin User
 */
class UserResource extends JsonResource
{
    private bool $forceIncludeEmail = false;

    /**
     * Mark this resource as representing the caller's own account, e.g. from
     * AuthController where the request is authenticated by credentials rather than by
     * the `auth:sanctum` middleware, so $request->user() isn't populated yet.
     */
    public function asSelf(): static
    {
        $this->forceIncludeEmail = true;

        return $this;
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $isSelf = $this->forceIncludeEmail || ($request->user()?->is($this->resource) ?? false);

        return [
            'id' => $this->id,
            'name' => $this->name,
            // Email, phone, moderation status, and the handover-radius setting are
            // only ever returned to the account they belong to — never when viewing
            // someone else's profile.
            'email' => $this->when($isSelf, $this->email),
            'phone' => $this->when($isSelf, $this->phone),
            'show_handover_radius' => $this->when($isSelf, (bool) $this->show_handover_radius),
            'is_suspended' => $this->when($isSelf, (bool) $this->is_suspended),
            'suspension_reason' => $this->when($isSelf, $this->suspension_reason),
            // Public trust signal (shown on listing/seller cards to other users),
            // unlike email/suspension which are private to the account itself.
            'is_verified' => $this->verified_at !== null,
            'username' => $this->username,
            'bio' => $this->bio,
            'avatar_url' => $this->resource->avatarUrl(),
            'cover_photo_url' => $this->resource->coverPhotoUrl(),
            'location_label' => $this->location_label,
            'growing_interests' => $this->growing_interests ?? [],
            'experience_level' => $this->experience_level?->value,
            'growing_setup' => $this->growing_setup?->value,
            'rating_avg' => (float) $this->rating_avg,
            'location' => $this->fuzzyLocationArray($isSelf),
            'posts_count' => $this->whenCounted('posts'),
            'active_listings_count' => $this->when(
                array_key_exists('active_listings_count', $this->resource->getAttributes()),
                fn () => (int) $this->active_listings_count,
            ),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }

    /**
     * Prefers coordinates already loaded via scopeSelectFuzzyCoordinates() to avoid an
     * N+1 query; falls back to a direct lookup for a single-resource response.
     *
     * Null when viewing someone else's profile who has turned off
     * `show_handover_radius` — the one real effect that setting has.
     *
     * @return array{latitude: float, longitude: float}|null
     */
    private function fuzzyLocationArray(bool $isSelf): ?array
    {
        if (! $isSelf && ! $this->show_handover_radius) {
            return null;
        }

        if ($this->fuzzy_location_latitude !== null && $this->fuzzy_location_longitude !== null) {
            return [
                'latitude' => (float) $this->fuzzy_location_latitude,
                'longitude' => (float) $this->fuzzy_location_longitude,
            ];
        }

        return $this->resource->getFuzzyCoordinates();
    }
}
