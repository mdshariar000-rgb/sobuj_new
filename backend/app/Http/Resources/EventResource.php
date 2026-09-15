<?php

namespace App\Http\Resources;

use App\Enums\EventAttendeeStatus;
use App\Models\Event;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\Storage;

/**
 * @mixin Event
 */
class EventResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'group_id' => $this->group_id,
            'title' => $this->title,
            'description' => $this->description,
            'format' => $this->format->value,
            'format_label' => $this->format->label(),
            'category' => $this->category,
            'cover_image_url' => $this->cover_image_path !== null
                ? Storage::disk('public')->url($this->cover_image_path)
                : null,
            'location' => $this->location,
            'starts_at' => $this->starts_at?->toIso8601String(),
            'ends_at' => $this->ends_at?->toIso8601String(),
            'capacity' => $this->capacity,
            'status' => $this->status->value,
            'status_label' => $this->status->label(),
            'attendees_count' => $this->whenCounted('attendees'),
            // A small preview of who's registered, newest RSVP first — only
            // present when the full `attendees` relation was eager-loaded (see
            // EventController::show()), not on the paginated index.
            'attendees_preview' => $this->when(
                $this->relationLoaded('attendees'),
                fn () => UserResource::collection(
                    $this->attendees
                        ->sortByDesc(fn ($user) => $user->pivot->rsvped_at)
                        ->take(8)
                        ->values(),
                ),
            ),
            'is_saved' => $this->when(
                array_key_exists('is_saved', $this->resource->getAttributes()),
                fn () => (bool) $this->is_saved,
            ),
            'host' => new UserResource($this->whenLoaded('host')),
            'group' => new GroupResource($this->whenLoaded('group')),
            // Two ways this gets populated depending on the endpoint: index() uses
            // addSelect() (a cheap correlated-subquery column aliased onto this same
            // `my_rsvp_status` attribute — see EventController::index()); show()/
            // rsvp() eager-load the full `attendees` relation instead and this falls
            // back to reading it directly.
            'my_rsvp_status' => $this->when(
                $request->user() !== null && ($this->relationLoaded('attendees') || array_key_exists('my_rsvp_status', $this->resource->getAttributes())),
                function () use ($request) {
                    if ($this->relationLoaded('attendees')) {
                        $attendee = $this->attendees->firstWhere('id', $request->user()->id);

                        /** @var EventAttendeeStatus|null $status */
                        $status = $attendee?->pivot?->status;

                        return $status?->value;
                    }

                    return $this->resource->getAttributes()['my_rsvp_status'];
                },
            ),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
