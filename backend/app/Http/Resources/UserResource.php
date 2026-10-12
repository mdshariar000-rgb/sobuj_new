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
            // The label often starts with the full postcode ("LU2 0HR, High
            // Town, Luton"), which pins someone down to a few houses — only
            // the account itself sees that; everyone else gets the area.
            'location_label' => $isSelf
                ? $this->location_label
                : self::withoutPostcode($this->location_label),
            // Private: only the user themselves (and admins, on the panel).
            'address' => $this->when($isSelf, fn () => [
                'line1' => $this->address_line1,
                'line2' => $this->address_line2,
                'city' => $this->address_city,
                'county' => $this->address_county,
                'postcode' => $this->address_postcode,
            ]),
            // Accounts made before the address was required — the app asks
            // for it before letting them continue.
            'needs_address' => $this->when($isSelf, fn () => $this->address_postcode === null),
            // False for a Google/Apple account with no password yet: deleting
            // it confirms with that provider instead (see AuthController::destroy).
            'has_password' => $this->when($isSelf, fn () => (bool) ($this->has_password ?? true)),
            'signed_in_with' => $this->when($isSelf, fn () => array_values(array_filter([
                $this->google_id !== null ? 'google' : null,
                $this->apple_id !== null ? 'apple' : null,
            ]))),
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
            // Only on GET /users/{id} — see UserController::show().
            'seller_rating' => $this->when(
                array_key_exists('seller_rating', $this->resource->getAttributes()),
                fn () => $this->seller_rating,
            ),
            'seller_reviews_count' => $this->when(
                array_key_exists('seller_reviews_count', $this->resource->getAttributes()),
                fn () => (int) $this->seller_reviews_count,
            ),
            'completed_deals_count' => $this->when(
                array_key_exists('completed_deals_count', $this->resource->getAttributes()),
                fn () => (int) $this->completed_deals_count,
            ),
            'followers_count' => $this->whenCounted('followers'),
            'following_count' => $this->whenCounted('following'),
            // Only set where a viewer's identity is meaningful (a single-resource
            // profile response) — never on a list a viewer isn't looking at one
            // account through, same reasoning as PostResource::liked_by_me.
            'is_following' => $this->when(
                array_key_exists('is_following', $this->resource->getAttributes()),
                fn () => (bool) $this->is_following,
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

    /**
     * Drops any UK postcode (full, like "LU2 0HR", or just its first half,
     * like "LU2") from a comma-separated location label.
     */
    public static function withoutPostcode(?string $label): ?string
    {
        if ($label === null) {
            return null;
        }

        $parts = array_filter(
            array_map('trim', explode(',', $label)),
            fn (string $part) => $part !== ''
                && ! preg_match('/^[A-Z]{1,2}\d[A-Z\d]?(\s*\d[A-Z]{2})?$/i', $part),
        );

        return $parts === [] ? null : implode(', ', $parts);
    }
}
