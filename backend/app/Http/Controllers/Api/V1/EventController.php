<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\EventAttendeeStatus;
use App\Enums\EventStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Event\RsvpEventRequest;
use App\Http\Requests\Event\StoreEventRequest;
use App\Http\Requests\Event\UpdateEventRequest;
use App\Http\Resources\EventResource;
use App\Http\Resources\GroupResource;
use App\Models\Event;
use App\Models\EventAttendee;
use App\Services\AutoGroupService;
use App\Services\EventChatService;
use App\Services\ImageService;
use Carbon\Carbon;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class EventController extends Controller
{
    private const PER_PAGE = 20;

    /**
     * Published, not-yet-expired events, soonest first. Draft/canceled
     * events are only visible on the host's own management view (not built
     * here — same pattern as ListingController::index() for owner-scoped
     * listings if that's needed later).
     *
     * "Expired" means its end time (or start time, if it has no end time)
     * has already passed — an event already underway still shows until it
     * actually ends, rather than disappearing the instant its start time
     * ticks over. This only applies to the plain timeline: ?month=YYYY-MM
     * (the Events tab's calendar view) deliberately still returns every
     * event in that month, past or future, since browsing a past month is
     * for looking back at what already happened.
     *
     * ?category= narrows to one admin-managed event category name (see
     * EventCategory) — backs the Events tab's filter chips; omitted (the
     * "All Events" chip) shows every category, soonest first.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $request->validate([
            'month' => ['nullable', 'date_format:Y-m'],
            'category' => ['nullable', 'string', Rule::exists('event_categories', 'name')],
            'for_you' => ['nullable', 'boolean'],
            'search' => ['nullable', 'string', 'max:100'],
            'going' => ['nullable', 'boolean'],
        ]);
        $userId = $request->user()->id;
        // Events store their place as free text, so "near you" means the
        // place mentions the viewer's city or town.
        $city = trim((string) $request->user()->address_city)
            ?: AutoGroupService::townFrom($request->user()->location_label);

        $events = Event::query()
            ->where('status', EventStatus::Published)
            ->whereNotIn('host_id', $request->user()->hiddenUserIds())
            ->when($request->filled('group_id'), fn ($query) => $query->where('group_id', $request->integer('group_id')))
            // Title, place, description or host name.
            ->when($request->filled('search'), function ($query) use ($request) {
                $term = '%'.addcslashes(trim((string) $request->string('search')), '%_\\').'%';
                $query->where(fn ($query) => $query
                    ->where('title', 'like', $term)
                    ->orWhere('location', 'like', $term)
                    ->orWhere('description', 'like', $term)
                    ->orWhereHas('host', fn ($query) => $query->where('name', 'like', $term)));
            })
            // "Going" on the My events tab.
            ->when($request->boolean('going'), fn ($query) => $query->whereHas(
                'attendees',
                fn ($query) => $query->where('users.id', $userId)->where('event_attendees.status', EventAttendeeStatus::Going),
            ))
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
            }, function ($query) {
                $query->where(function ($query) {
                    $query->where('ends_at', '>=', now())
                        ->orWhere(function ($query) {
                            $query->whereNull('ends_at')->where('starts_at', '>=', now());
                        });
                });
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
            ->when($city !== null && $city !== '', fn ($query) => $query->selectRaw(
                'LOWER(events.location) LIKE ? as near_you',
                ['%'.addcslashes(Str::lower($city), '%_\\').'%'],
            ))
            // ?for_you=1 — the "All Events" list: events near the user first,
            // then ones in their groups or hosted by people they follow.
            ->when($request->boolean('for_you') && $city !== null && $city !== '', fn ($query) => $query->orderByDesc('near_you'))
            ->when($request->boolean('for_you'), fn ($query) => $query->orderByRaw(
                'CASE WHEN group_id IN (SELECT group_id FROM group_members WHERE user_id = ?)'
                .' OR host_id IN (SELECT followed_id FROM user_follows WHERE follower_id = ?)'
                .' THEN 0 ELSE 1 END',
                [$userId, $userId],
            ))
            ->orderBy('starts_at')
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return EventResource::collection($events);
    }

    /**
     * The caller's own hosted events, newest first — ?status=draft is the
     * "My drafts" list (index() only ever shows published events).
     */
    public function mine(Request $request): AnonymousResourceCollection
    {
        $request->validate(['status' => ['nullable', Rule::enum(EventStatus::class)]]);

        $events = Event::query()
            ->where('host_id', $request->user()->id)
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->withCount('attendees')
            ->with(['host', 'group'])
            ->latest('updated_at')
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return EventResource::collection($events);
    }

    /**
     * Events this user has bookmarked, most recently saved first — the
     * "Saved Events" list. Unlike index(), this intentionally doesn't filter
     * out expired events: a saved event that already happened is still
     * something the user chose to keep, not something to hide.
     */
    public function saved(Request $request): AnonymousResourceCollection
    {
        $events = $request->user()
            ->savedEvents()
            ->withCount('attendees')
            ->addSelect(['my_rsvp_status' => EventAttendee::query()
                ->select('status')
                ->whereColumn('event_id', 'events.id')
                ->where('user_id', $request->user()->id)
                ->limit(1),
            ])
            ->with(['host', 'group'])
            ->orderBy('saved_events.created_at', 'desc')
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        $events->getCollection()->each(
            fn (Event $event) => $event->setAttribute('is_saved', true),
        );

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
                'registration_fee' => $data['registration_fee'] ?? null,
                'proposed_dates' => $data['proposed_dates'] ?? null,
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
                'title', 'description', 'format', 'category', 'location', 'starts_at', 'ends_at', 'capacity',
                'registration_fee', 'proposed_dates', 'status',
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

    /**
     * The event's conversation — a hidden group chat only the host and
     * "going" attendees can open (see EventChatService). The app then uses
     * the ordinary group chat endpoints with the returned group's id.
     */
    public function chat(Request $request, Event $event, EventChatService $chats): JsonResponse
    {
        abort_if($event->status !== EventStatus::Published, 404);
        abort_unless(
            $chats->canChat($event, $request->user()),
            403,
            'Only people going to this event can join its chat.',
        );

        $group = $chats->chatFor($event)->load('members')->loadCount('members');

        // Always 200 — even on the open that first creates the chat.
        return (new GroupResource($group))->response()->setStatusCode(200);
    }

    public function rsvp(RsvpEventRequest $request, Event $event, EventChatService $chats): EventResource
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

        $chats->syncAttendee($event, $user);

        return new EventResource($event->fresh(['host', 'group', 'attendees'])->loadCount('attendees'));
    }

    public function cancelRsvp(Request $request, Event $event, EventChatService $chats): JsonResponse
    {
        $event->attendees()->detach($request->user()->id);
        $chats->syncAttendee($event, $request->user());

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
