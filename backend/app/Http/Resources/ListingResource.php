<?php

namespace App\Http\Resources;

use App\Models\Listing;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin Listing
 */
class ListingResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'variety' => $this->variety,
            'description' => $this->description,
            'condition' => $this->condition?->value,
            'condition_label' => $this->condition?->label(),
            'listing_type' => $this->listing_type,
            'transaction_type' => $this->transaction_type->value,
            'price' => $this->price !== null ? (float) $this->price : null,
            'quantity' => $this->quantity,
            // Private: buyers ask for contact details in chat, so only the
            // seller (and admins) ever get it back.
            'contact' => $this->when(
                $request->user()?->id === $this->user_id || (bool) $request->user()?->is_admin,
                fn () => $this->contact,
            ),
            'status' => $this->status->value,
            'looking_for' => $this->looking_for,
            'handover_note' => $this->handover_note,
            'location' => $this->fuzzyLocationArray($request),
            // Only present when the query came through Listing::nearby() (Discovery)
            // and the owner hasn't turned off Community Handover Radius.
            'distance_km' => $this->when(
                isset($this->distance_meters) && $this->locationVisibleTo($request),
                fn () => round($this->distance_meters / 1000, 2),
            ),
            'views_count' => (int) $this->views_count,
            'average_rating' => $this->when(
                array_key_exists('reviews_avg_rating', $this->resource->getAttributes()),
                fn () => $this->reviews_avg_rating !== null ? round((float) $this->reviews_avg_rating, 1) : null,
            ),
            'reviews_count' => $this->when(
                array_key_exists('reviews_count', $this->resource->getAttributes()),
                fn () => (int) $this->reviews_count,
            ),
            'photos' => ListingPhotoResource::collection($this->whenLoaded('photos')),
            'is_saved' => $this->when(
                array_key_exists('is_saved', $this->resource->getAttributes()),
                fn () => (bool) $this->is_saved,
            ),
            // Only on a single-listing fetch: whether the caller completed a
            // deal for it and so may leave a review.
            'can_review' => $this->when(
                array_key_exists('can_review', $this->resource->getAttributes()),
                fn () => (bool) $this->can_review,
            ),
            'owner' => new UserResource($this->whenLoaded('user')),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }

    /**
     * Whether this listing's approximate location should be shown to the current
     * viewer — false when the owner has turned off "Community Handover Radius" and
     * the viewer isn't the owner themselves. Defaults to visible when the `user`
     * relation isn't loaded, so endpoints that don't eager-load it keep their
     * existing behavior rather than silently hiding location.
     */
    private function locationVisibleTo(Request $request): bool
    {
        if (! $this->resource->relationLoaded('user') || $this->resource->user === null) {
            return true;
        }

        $owner = $this->resource->user;

        return $request->user()?->is($owner) || (bool) $owner->show_handover_radius;
    }

    /**
     * Prefers coordinates already loaded via scopeSelectFuzzyCoordinates() to avoid an
     * N+1 query per row on paginated listing endpoints; falls back to a direct lookup
     * for a single-resource response.
     *
     * @return array{latitude: float, longitude: float}|null
     */
    private function fuzzyLocationArray(Request $request): ?array
    {
        if (! $this->locationVisibleTo($request)) {
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
