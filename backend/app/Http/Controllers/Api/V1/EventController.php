<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\EventAttendeeStatus;
use App\Enums\EventStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Event\RsvpEventRequest;
use App\Http\Requests\Event\StoreEventRequest;
use App\Http\Requests\Event\UpdateEventRequest;
use App\Http\Resources\EventResource;
use App\Models\Event;
use App\Models\EventAttendee;
use App\Services\ImageService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class EventController extends Controller
{
    private const PER_PAGE = 20;

    /**
     * Published events, soonest first. Draft/canceled events are only visible
     * on the host's own management view (not built here — same pattern as
     * ListingController::index() for owner-scoped listings if that's needed
     * later).
     *
     * ?month=YYYY-MM narrows to that calendar month — backs the Events tab's
     * calendar view, which needs every event in the visible month rather
     * than just the next PER_PAGE soonest ones.
     * ?category= narrows to one admin-managed event category name (see
     * EventCategory) — backs the Events tab's filter chips; omitted (the
     * "All Events" chip) shows every category, soonest first.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate([
            'month' => ['nullable', 'date_format:Y-m'],
            'category' => ['nullable', 'string', Rule::exists('event_categories', 'name')],
        ]);

        $events = Event::query()
            ->where('status', EventStatus::Published)
            ->when($request->filled('group_id'), fn ($query) => $query->where('group_id', $request->integer('group_id')))
            ->when(
                $request->filled('category'),
                fn ($query) => $query->where('category', $request->string('category')),
            )
            ->when($request->filled('month'), function ($query) use ($request) {
                $month = Carbon::createFromFormat('Y-m', $request->string('month'));
                $query->whereBetween('starts_at', [
                    $month->copy()->startOfMonth(),
                    $month->copy()->endOfMonth(),
                ]);
            })
            ->withCount('attendees')
            // A cheap correlated-subquery column rather than eager-loading every
            // event's full attendee list just to read one user's RSVP status — see
            // EventResource::my_rsvp_status, which reads this same column.
            ->addSelect(['my_rsvp_status' => EventAttendee::query()
                ->select('status')
                ->whereColumn('event_id', 'events.id')
                ->where('user_id', $request->user()->id)
                ->limit(1),
            ])
            // Cheap correlated-subquery boolean rather than eager-loading every
            // event's full saved-by list — same pattern as ListingController::index().
            ->addSelect(['is_saved' => DB::table('saved_events')
                ->selectRaw('1')
                ->whereColumn('event_id', 'events.id')
                ->where('user_id', $request->user()->id)
                ->limit(1),
            ])
            ->with(['host', 'group'])
            ->orderBy('starts_at')
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return EventResource::collection($events);
    }

    public function store(StoreEventRequest $request, ImageService $imageService): JsonResponse
    {
        $data = $request->validated();
        $user = $request->user();

        $event = DB::transaction(function () use ($data, $user, $request, $imageService) {
            $event = new Event([
                'group_id' => $data['group_id'] ?? null,
                'title' => $data['title'],
                'description' => $data['description'] ?? null,
                'format' => $data['format'],
                'category' => $data['category'] ?? null,
                'location' => $data['location'] ?? null,
                'starts_at' => $data['starts_at'],
                'ends_at' => $data['ends_at'] ?? null,
                'capacity' => $data['capacity'] ?? null,
                'status' => $data['status'] ?? EventStatus::Draft,
            ]);
            $event->host_id = $user->id;

            if ($request->hasFile('cover_image')) {
                $event->cover_image_path = $imageService->store($request->file('cover_image'), 'events');
            }

            $event->save();

            return $event;
        });

        return (new EventResource($event->fresh(['host', 'group'])))
            ->response()
            ->setStatusCode(201);
    }

    public function show(Request $request, Event $event): EventResource
    {
        $event->loadCount('attendees')->loadMissing(['host', 'group']);

        if ($request->user() !== null) {
            $event->loadMissing('attendees');
            $event->setAttribute(
                'is_saved',
                $event->savedBy()->where('user_id', $request->user()->id)->exists(),
            );
        }

        return new EventResource($event);
    }

    public function update(UpdateEventRequest $request, Event $event, ImageService $imageService): EventResource
    {
        $this->authorize('update', $event);

        $data = $request->validated();

        DB::transaction(function () use ($data, $event, $request, $imageService) {
            $event->fill(array_intersect_key($data, array_flip([
                'title', 'description', 'format', 'category', 'location', 'starts_at', 'ends_at', 'capacity', 'status',
            ])));

            if ($request->hasFile('cover_image')) {
                $event->cover_image_path = $imageService->store($request->file('cover_image'), 'events');
            }

            $event->save();
        });

        return new EventResource($event->fresh(['host', 'group']));
    }

    public function destroy(Event $event): JsonResponse
    {
        $this->authorize('delete', $event);

        $event->delete();

        return response()->json(['message' => 'Event deleted.']);
    }

    public function rsvp(RsvpEventRequest $request, Event $event): EventResource
    {
        $user = $request->user();
        $status = EventAttendeeStatus::from($request->validated('status'));

        if ($event->attendees()->where('user_id', $user->id)->exists()) {
            $event->attendees()->updateExistingPivot($user->id, [
                'status' => $status,
                'rsvped_at' => now(),
            ]);
        } else {
            $event->attendees()->attach($user->id, [
                'status' => $status,
                'rsvped_at' => now(),
            ]);
        }

        return new EventResource($event->fresh(['host', 'group', 'attendees'])->loadCount('attendees'));
    }

    public function cancelRsvp(Request $request, Event $event): JsonResponse
    {
        $event->attendees()->detach($request->user()->id);

        return response()->json(['message' => 'RSVP canceled.']);
    }

    public function save(Request $request, Event $event): EventResource
    {
        $event->savedBy()->syncWithoutDetaching([$request->user()->id]);

        $event->loadCount('attendees')->loadMissing(['host', 'group']);
        $event->setAttribute('is_saved', true);

        return new EventResource($event);
    }

    public function unsave(Request $request, Event $event): EventResource
    {
        $event->savedBy()->detach($request->user()->id);

        $event->loadCount('attendees')->loadMissing(['host', 'group']);
        $event->setAttribute('is_saved', false);

        return new EventResource($event);
    }
}
