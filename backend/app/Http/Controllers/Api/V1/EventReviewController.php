<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\EventStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\EventReviewResource;
use App\Models\Event;
use App\Models\EventReview;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * Reviews and comments on an event — past or upcoming — from the events
 * calendar.
 */
class EventReviewController extends Controller
{
    private const PER_PAGE = 30;

    public function index(Request $request, Event $event): AnonymousResourceCollection
    {
        $reviews = $event->reviews()
            ->whereNotIn('user_id', $request->user()->hiddenUserIds())
            ->with('user')
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return EventReviewResource::collection($reviews);
    }

    public function store(Request $request, Event $event): JsonResponse
    {
        abort_if($event->status !== EventStatus::Published, 404);

        $user = $request->user();
        abort_if($user->hasBlockRelationWith($event->host_id), 404);

        $data = $request->validate([
            'rating' => ['nullable', 'integer', 'between:1,5', 'required_without:body'],
            'body' => ['nullable', 'string', 'max:2000', 'required_without:rating'],
        ]);

        $review = new EventReview($data);
        $review->event_id = $event->id;
        $review->user_id = $user->id;
        $review->save();

        return (new EventReviewResource($review->load('user')))
            ->response()
            ->setStatusCode(201);
    }

    public function destroy(Request $request, Event $event, EventReview $review): JsonResponse
    {
        abort_if((int) $review->event_id !== $event->id, 404);

        $user = $request->user();
        abort_unless($user->is_admin || (int) $review->user_id === $user->id, 403);

        $review->delete();

        return response()->json(['message' => 'Review deleted.']);
    }
}
