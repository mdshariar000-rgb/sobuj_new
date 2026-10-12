<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\NotificationType;
use App\Http\Controllers\Controller;
use App\Http\Requests\ListingReview\StoreListingReviewRequest;
use App\Http\Resources\ListingReviewResource;
use App\Models\Listing;
use App\Models\ListingReview;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

/**
 * Star rating + comment on a listing — distinct from a swap offer's message
 * thread (that's negotiation; this is public feedback shown on the listing's
 * detail screen, one per grower per listing, editable in place).
 */
class ListingReviewController extends Controller
{
    private const PER_PAGE = 30;

    public function index(Request $request, Listing $listing): AnonymousResourceCollection
    {
        $reviews = $listing->reviews()
            ->whereNotIn('reviewer_id', $request->user()->hiddenUserIds())
            ->with('reviewer')
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return ListingReviewResource::collection($reviews);
    }

    /**
     * Idempotent upsert, same pattern as FollowController::store() — posting
     * again just replaces the reviewer's existing rating/comment for this
     * listing rather than erroring or stacking a second row (the unique
     * (listing_id, reviewer_id) index on listing_reviews backs this).
     */
    public function store(
        StoreListingReviewRequest $request,
        Listing $listing,
        NotificationService $notificationService,
    ): JsonResponse {
        $reviewer = $request->user();

        if ((int) $listing->user_id === $reviewer->id) {
            throw ValidationException::withMessages([
                'listing' => ['You cannot review your own listing.'],
            ]);
        }

        abort_if($reviewer->hasBlockRelationWith($listing->user_id), 404);

        // Editing an existing review stays allowed; a new one needs a
        // completed deal.
        $hasReviewed = $listing->reviews()->where('reviewer_id', $reviewer->id)->exists();
        if (! $hasReviewed && ! $listing->canBeReviewedBy($reviewer)) {
            throw ValidationException::withMessages([
                'listing' => ['You can review this listing after completing a deal for it.'],
            ]);
        }

        $data = $request->validated();
        $isNewReview = ! $hasReviewed;

        // listing_id/reviewer_id aren't mass-assignable, so set them
        // explicitly (updateOrCreate would silently drop them).
        $review = $listing->reviews()->where('reviewer_id', $reviewer->id)->first()
            ?? new ListingReview;
        $review->forceFill([
            'listing_id' => $listing->id,
            'reviewer_id' => $reviewer->id,
            'rating' => $data['rating'],
            'comment' => $data['comment'] ?? null,
        ])->save();

        if ($isNewReview) {
            $notificationService->notify(
                $listing->user,
                $reviewer,
                NotificationType::ListingReviewed,
                "{$reviewer->name} reviewed your listing \"{$listing->title}\"",
                $review->comment !== null
                    ? Str::limit($review->comment, 100)
                    : "{$review->rating}-star rating",
                ['listing_id' => $listing->id, 'listing_review_id' => $review->id],
            );
        }

        return (new ListingReviewResource($review->fresh('reviewer')))
            ->response()
            ->setStatusCode($isNewReview ? 201 : 200);
    }

    public function destroy(Listing $listing, ListingReview $review): JsonResponse
    {
        abort_if((int) $review->listing_id !== $listing->id, 404);

        $this->authorize('delete', $review);

        $review->delete();

        return response()->json(['message' => 'Review deleted.']);
    }
}
