<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\ListingStatus;
use App\Enums\MessageType;
use App\Enums\SwapOfferStatus;
use App\Events\MessageSent;
use App\Events\SwapStatusUpdated;
use App\Http\Controllers\Controller;
use App\Http\Requests\SwapOffer\StoreSwapOfferRequest;
use App\Http\Requests\SwapOffer\UpdateSwapOfferStatusRequest;
use App\Http\Resources\SwapOfferResource;
use App\Models\Listing;
use App\Models\SwapOffer;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SwapOfferController extends Controller
{
    private const PER_PAGE = 20;

    /**
     * Offers involving the authenticated user, either as the requester or as the
     * owner of the listing an offer was made against.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $request->user();
        $hiddenUserIds = $user->hiddenUserIds();

        $offers = SwapOffer::query()
            ->where(function ($query) use ($user) {
                $query->where('requester_id', $user->id)
                    ->orWhereHas('listing', fn ($listingQuery) => $listingQuery->where('user_id', $user->id));
            })
            // Threads with a blocked (or blocking) user drop out of the inbox.
            ->whereNotIn('requester_id', $hiddenUserIds)
            ->whereDoesntHave('listing', fn ($listingQuery) => $listingQuery->whereIn('user_id', $hiddenUserIds))
            ->with(['listing.photos', 'listing.user', 'requester', 'latestMessage'])
            ->withCount(['messages as unread_count' => function ($query) use ($user) {
                $query->whereNull('read_at')
                    ->where(fn ($q) => $q->whereNull('sender_id')->orWhere('sender_id', '!=', $user->id));
            }])
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return SwapOfferResource::collection($offers);
    }

    public function show(Request $request, SwapOffer $swapOffer): SwapOfferResource
    {
        $this->authorize('view', $swapOffer);

        $user = $request->user();
        $swapOffer->loadMissing(['listing.photos', 'listing.user', 'requester'])
            ->loadCount(['messages as unread_count' => function ($query) use ($user) {
                $query->whereNull('read_at')
                    ->where(fn ($q) => $q->whereNull('sender_id')->orWhere('sender_id', '!=', $user->id));
            }]);

        return new SwapOfferResource($swapOffer);
    }

    /**
     * Propose a swap on someone else's active listing. Always starts `pending`.
     *
     * Idempotent per requester+listing while an offer is still open: tapping
     * Contact/Request/Propose Trade/"I Have This" again (e.g. from a second visit to
     * the listing) reopens the existing thread instead of spawning a duplicate offer
     * — mirroring how a messaging app reuses one conversation per contact rather than
     * starting a new one on every tap.
     */
    public function store(StoreSwapOfferRequest $request, Listing $listing): JsonResponse
    {
        $user = $request->user();

        if ($listing->user_id === $user->id) {
            throw ValidationException::withMessages([
                'listing_id' => ['You cannot make an offer on your own listing.'],
            ]);
        }

        abort_if($user->hasBlockRelationWith($listing->user_id), 403, "You can't make an offer to this user.");

        $existing = SwapOffer::query()
            ->where('listing_id', $listing->id)
            ->where('requester_id', $user->id)
            ->whereIn('status', [SwapOfferStatus::Pending, SwapOfferStatus::Countered, SwapOfferStatus::Accepted])
            ->first();

        if ($existing !== null) {
            // 200, not 201 — reopening an existing thread, not creating a new resource.
            return (new SwapOfferResource($existing->loadMissing(['listing.photos', 'listing.user', 'requester'])))
                ->response()
                ->setStatusCode(200);
        }

        if ($listing->status !== ListingStatus::Active) {
            throw ValidationException::withMessages([
                'listing_id' => ['This listing is not currently accepting offers.'],
            ]);
        }

        $swapOffer = DB::transaction(function () use ($request, $listing, $user) {
            $swapOffer = SwapOffer::create([
                'listing_id' => $listing->id,
                'requester_id' => $user->id,
                'status' => SwapOfferStatus::Pending,
                'offer_details' => $request->validated('offer_details'),
            ]);

            $this->postSystemMessage($swapOffer, "{$user->name} made an offer on \"{$listing->title}\".");

            return $swapOffer;
        });

        broadcast(new SwapStatusUpdated($swapOffer));

        return (new SwapOfferResource($swapOffer->fresh(['listing', 'listing.user', 'requester'])))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * Move the offer to a new status. Valid transitions and which side (listing owner
     * vs. requester) may make them are entirely defined by SwapOfferPolicy::respond().
     */
    public function updateStatus(UpdateSwapOfferStatusRequest $request, SwapOffer $swapOffer): SwapOfferResource
    {
        $newStatus = SwapOfferStatus::from($request->validated('status'));
        $user = $request->user();

        $this->authorize('respond', [$swapOffer, $newStatus]);

        DB::transaction(function () use ($swapOffer, $newStatus, $request, $user) {
            $swapOffer->status = $newStatus;

            if ($newStatus === SwapOfferStatus::Countered && $request->filled('offer_details')) {
                $swapOffer->offer_details = $request->validated('offer_details');
            }

            $swapOffer->save();

            $this->postSystemMessage($swapOffer, $this->transitionMessage($newStatus, $user));
        });

        broadcast(new SwapStatusUpdated($swapOffer));

        return new SwapOfferResource($swapOffer->fresh(['listing', 'listing.user', 'requester']));
    }

    /**
     * Creates the system_event message and broadcasts it to the thread. Not wrapped in
     * ->toOthers(): unlike a chat message the sender's own client optimistically
     * renders, nobody has this system message locally yet, so everyone (including the
     * acting user) should receive it over the socket.
     */
    private function postSystemMessage(SwapOffer $swapOffer, string $body): void
    {
        $message = $swapOffer->messages()->create([
            'sender_id' => null,
            'message_type' => MessageType::SystemEvent,
            'body' => $body,
        ]);

        broadcast(new MessageSent($message));
    }

    private function transitionMessage(SwapOfferStatus $status, User $actor): string
    {
        return match ($status) {
            SwapOfferStatus::Accepted => "{$actor->name} accepted the offer.",
            SwapOfferStatus::Countered => "{$actor->name} sent a counter-offer.",
            SwapOfferStatus::Declined => "{$actor->name} declined the offer.",
            SwapOfferStatus::Canceled => "{$actor->name} canceled the offer.",
            SwapOfferStatus::Completed => "{$actor->name} marked the swap as completed.",
            SwapOfferStatus::Pending => "{$actor->name} reset the offer to pending.",
        };
    }
}
