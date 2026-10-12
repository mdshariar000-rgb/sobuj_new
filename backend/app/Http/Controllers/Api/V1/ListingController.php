<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\ListingStatus;
use App\Enums\MessageType;
use App\Enums\SwapOfferStatus;
use App\Events\MessageSent;
use App\Http\Controllers\Controller;
use App\Http\Requests\Listing\StoreListingRequest;
use App\Http\Requests\Listing\UpdateListingRequest;
use App\Http\Resources\ListingResource;
use App\Models\Listing;
use App\Models\User;
use App\Services\ImageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class ListingController extends Controller
{
    private const PER_PAGE = 20;

    /**
     * The authenticated user's own listings (including reserved/completed/deleted —
     * this is their management view, not the public discovery feed).
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $listings = $request->user()
            ->listings()
            ->selectFuzzyCoordinates()
            ->with('photos')
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return ListingResource::collection($listings);
    }

    /**
     * The authenticated user's saved/"favorited" listings — everything they've
     * tapped the heart icon on, most recently saved first. Logically-deleted
     * listings are excluded (they'd 404 if tapped, same rule as show()).
     */
    public function saved(Request $request): AnonymousResourceCollection
    {
        $listings = $request->user()
            ->savedListings()
            ->where('status', '!=', ListingStatus::Deleted)
            ->whereNotIn('listings.user_id', $request->user()->hiddenUserIds())
            ->selectFuzzyCoordinates()
            ->with(['photos', 'user'])
            ->orderBy('saved_listings.created_at', 'desc')
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        $listings->getCollection()->each(
            fn (Listing $listing) => $listing->setAttribute('is_saved', true),
        );

        return ListingResource::collection($listings);
    }

    public function store(StoreListingRequest $request, ImageService $imageService): JsonResponse
    {
        $data = $request->validated();
        $user = $request->user();

        [$latitude, $longitude] = $this->resolveLocation($data, $user);

        $listing = DB::transaction(function () use ($data, $user, $latitude, $longitude, $request, $imageService) {
            $listing = new Listing([
                'title' => $data['title'],
                'variety' => $data['variety'] ?? null,
                'description' => $data['description'] ?? null,
                'condition' => $data['condition'] ?? null,
                'listing_type' => $data['listing_type'],
                'transaction_type' => $data['transaction_type'],
                'price' => $data['price'] ?? null,
                'quantity' => $data['quantity'] ?? null,
                'contact' => $data['contact'] ?? null,
                'looking_for' => $data['looking_for'] ?? null,
                'handover_note' => $data['handover_note'] ?? null,
            ]);
            $listing->user_id = $user->id;
            $listing->setLocation($latitude, $longitude);
            $listing->save();

            $this->storePhotos($listing, $request->file('photos') ?? [], $imageService, startingAt: 0);

            return $listing;
        });

        $freshListing = $listing->fresh(['photos', 'user']);
        $freshListing->setAttribute('is_saved', false);

        return (new ListingResource($freshListing))
            ->response()
            ->setStatusCode(201);
    }

    public function show(Request $request, Listing $listing): ListingResource
    {
        // Logically-deleted listings (status enum, not a DB soft-delete) stay visible
        // to their own owner but 404 for everyone else.
        if ($listing->status === ListingStatus::Deleted && $listing->user_id !== $request->user()->id) {
            abort(404);
        }

        // A blocked (or blocking) user's listings are as good as gone.
        abort_if($request->user()->hasBlockRelationWith($listing->user_id), 404);

        // Doesn't count the owner viewing their own listing.
        if ($listing->user_id !== $request->user()->id) {
            $listing->increment('views_count');
        }

        $listing->loadMissing(['photos', 'user']);
        $listing->loadCount('reviews')->loadAvg('reviews', 'rating');
        $listing->setAttribute(
            'is_saved',
            $listing->savedBy()->where('user_id', $request->user()->id)->exists(),
        );
        $listing->setAttribute('can_review', $listing->canBeReviewedBy($request->user()));

        return new ListingResource($listing);
    }

    public function save(Request $request, Listing $listing): ListingResource
    {
        $listing->savedBy()->syncWithoutDetaching([$request->user()->id]);

        $listing->loadMissing(['photos', 'user']);
        $listing->setAttribute('is_saved', true);

        return new ListingResource($listing);
    }

    public function unsave(Request $request, Listing $listing): ListingResource
    {
        $listing->savedBy()->detach($request->user()->id);

        $listing->loadMissing(['photos', 'user']);
        $listing->setAttribute('is_saved', false);

        return new ListingResource($listing);
    }

    public function update(UpdateListingRequest $request, Listing $listing, ImageService $imageService): ListingResource
    {
        $this->authorize('update', $listing);

        $data = $request->validated();

        DB::transaction(function () use ($data, $listing, $request, $imageService) {
            $listing->fill(array_intersect_key($data, array_flip([
                'title', 'variety', 'description', 'condition', 'listing_type', 'transaction_type',
                'price', 'quantity', 'contact', 'looking_for', 'handover_note', 'status',
            ])));

            if (isset($data['latitude'], $data['longitude'])) {
                $listing->setLocation((float) $data['latitude'], (float) $data['longitude']);
            }

            $closing = $listing->isDirty('status')
                && in_array($listing->status, [ListingStatus::Completed, ListingStatus::Deleted], true);

            $listing->save();

            if (! empty($data['remove_photo_ids'])) {
                $listing->photos()->whereIn('id', $data['remove_photo_ids'])->delete();
            }

            if ($request->hasFile('photos')) {
                $nextOrder = ($listing->photos()->max('sort_order') ?? -1) + 1;
                $this->storePhotos($listing, $request->file('photos'), $imageService, startingAt: $nextOrder);
            }

            if ($closing) {
                $this->closeOpenOffers($listing);
            }
        });

        return new ListingResource($listing->fresh(['photos', 'user']));
    }

    /**
     * Logical delete only — flips status to `deleted` rather than removing the row, so
     * existing swap offers/messages/history referencing this listing stay intact.
     */
    public function destroy(Listing $listing): JsonResponse
    {
        $this->authorize('delete', $listing);

        DB::transaction(function () use ($listing) {
            $listing->update(['status' => ListingStatus::Deleted]);
            $this->closeOpenOffers($listing);
        });

        return response()->json(['message' => 'Listing deleted.']);
    }

    /**
     * @param  array{latitude?: string, longitude?: string}  $data
     * @return array{0: float, 1: float}
     */
    private function resolveLocation(array $data, User $user): array
    {
        if (isset($data['latitude'], $data['longitude'])) {
            return [(float) $data['latitude'], (float) $data['longitude']];
        }

        $exact = $user->getExactCoordinates();

        if (! $exact) {
            throw ValidationException::withMessages([
                'latitude' => ['A location is required; none was provided and none is on file for your account.'],
            ]);
        }

        return [$exact['latitude'], $exact['longitude']];
    }

    /**
     * @param  array<int, UploadedFile>  $files
     */
    /**
     * When the seller marks a listing sold or deletes it, every deal still
     * open on it is declined, with a note in its chat — same as completing
     * one deal does in SwapOfferController::syncListingStatus().
     */
    private function closeOpenOffers(Listing $listing): void
    {
        $open = $listing->swapOffers()
            ->whereIn('status', [SwapOfferStatus::Pending, SwapOfferStatus::Countered, SwapOfferStatus::Accepted])
            ->get();

        foreach ($open as $offer) {
            $offer->update(['status' => SwapOfferStatus::Declined]);
            $message = $offer->messages()->create([
                'sender_id' => null,
                'message_type' => MessageType::SystemEvent,
                'body' => "\"{$listing->title}\" is no longer available.",
            ]);
            broadcast(new MessageSent($message));
        }
    }

    private function storePhotos(Listing $listing, array $files, ImageService $imageService, int $startingAt): void
    {
        foreach (array_values($files) as $index => $file) {
            $path = $imageService->store($file, "listings/{$listing->id}");

            $listing->photos()->create([
                'path' => $path,
                'sort_order' => $startingAt + $index,
            ]);
        }
    }
}
