<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ListingResource;
use App\Models\Listing;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;

/**
 * The marketplace listings mixed into the Home feed, separate from the posts
 * query so the feed's pagination and ordering stay untouched:
 *
 *  - nearby: fresh listings near the viewer's registration location, ranked
 *    by distance, freshness and their growing interests (the "Fresh near
 *    you" carousel);
 *  - from_following: new listings from growers the viewer follows, shown in
 *    the feed as "<name> listed a new item" activity.
 */
class FeedMarketplaceController extends Controller
{
    private const NEARBY_LIMIT = 10;

    /** How many recent searches feed "Picked for you", and its size. */
    private const FOR_YOU_TERMS = 5;

    private const FOR_YOU_LIMIT = 20;

    private const NEARBY_CANDIDATES = 40;

    /** A seller gets at most this many cards, so one shop can't fill the carousel. */
    private const MAX_PER_SELLER = 2;

    private const FOLLOWING_LIMIT = 10;

    /** How new a listing must be to show up in the feed at all. */
    private const FRESH_DAYS = 14;

    private const RADIUS_METERS = 40_000;

    /** Used when the fresh, close search finds too little (a quiet area). */
    private const FALLBACK_DAYS = 60;

    private const FALLBACK_RADIUS_METERS = 100_000;

    private const MIN_NEARBY = 4;

    public function index(Request $request): JsonResponse
    {
        $viewer = $request->user();
        $coordinates = $viewer->getExactCoordinates();

        $fromFollowing = $this->fromFollowing($viewer, $coordinates);
        $nearby = $coordinates === null
            ? collect()
            : $this->nearby($viewer, $coordinates, $fromFollowing->pluck('id')->all());
        $forYou = $this->forYou($viewer, $coordinates);

        return response()->json([
            'data' => [
                'location_label' => $viewer->location_label,
                'nearby' => ListingResource::collection($nearby)->resolve($request),
                'from_following' => ListingResource::collection($fromFollowing)->resolve($request),
                'for_you' => ListingResource::collection($forYou)->resolve($request),
            ],
        ]);
    }

    /**
     * @param  array{latitude: float, longitude: float}  $coordinates
     * @param  list<int>  $excludeIds
     */
    private function nearby(User $viewer, array $coordinates, array $excludeIds): Collection
    {
        $search = fn (int $days, int $radius) => $this->baseQuery($viewer)
            ->whereKeyNot($excludeIds)
            ->where('listings.user_id', '!=', $viewer->id)
            // Already saved means already seen — the carousel is for discovery.
            ->whereDoesntHave('savedBy', fn ($query) => $query->where('users.id', $viewer->id))
            ->where('listings.created_at', '>=', now()->subDays($days))
            ->nearby($coordinates['latitude'], $coordinates['longitude'], $radius)
            ->limit(self::NEARBY_CANDIDATES)
            ->get();

        $candidates = $search(self::FRESH_DAYS, self::RADIUS_METERS);
        $windowDays = self::FRESH_DAYS;
        $radius = self::RADIUS_METERS;

        if ($candidates->count() < self::MIN_NEARBY) {
            $windowDays = self::FALLBACK_DAYS;
            $radius = self::FALLBACK_RADIUS_METERS;
            $candidates = $search($windowDays, $radius);
        }

        $interests = collect($viewer->growing_interests ?? [])
            ->map(fn ($interest) => Str::lower(trim((string) $interest)))
            ->filter(fn ($interest) => mb_strlen($interest) >= 3)
            ->values();

        $perSeller = [];

        return $candidates
            ->sortByDesc(fn (Listing $listing) => $this->score($listing, $interests, $windowDays, $radius))
            ->filter(function (Listing $listing) use (&$perSeller) {
                $perSeller[$listing->user_id] = ($perSeller[$listing->user_id] ?? 0) + 1;

                return $perSeller[$listing->user_id] <= self::MAX_PER_SELLER;
            })
            ->take(self::NEARBY_LIMIT)
            ->values();
    }

    /**
     * 0–1 each for closeness and freshness, plus a bump when the listing
     * matches one of the viewer's growing interests from registration.
     *
     * @param  Collection<int, string>  $interests
     */
    private function score(Listing $listing, Collection $interests, int $windowDays, int $radius): float
    {
        $closeness = 1 - min((float) $listing->distance_meters / $radius, 1);
        $ageDays = abs($listing->created_at->diffInHours(now())) / 24;
        $freshness = 1 - min($ageDays / $windowDays, 1);

        $haystack = Str::lower(implode(' ', [$listing->title, $listing->variety, $listing->listing_type]));
        $matchesInterest = $interests->contains(fn ($interest) => str_contains($haystack, $interest));

        return 0.5 * $closeness + 0.35 * $freshness + ($matchesInterest ? 0.3 : 0);
    }

    /**
     * @param  array{latitude: float, longitude: float}|null  $coordinates
     */
    /**
     * "Picked for you": newest listings matching what the viewer recently
     * searched for from Home (see SearchController). Empty until they search.
     */
    private function forYou(User $viewer, ?array $coordinates): Collection
    {
        $terms = $viewer->searchHistories()
            ->latest('updated_at')
            ->limit(self::FOR_YOU_TERMS)
            ->pluck('term');

        if ($terms->isEmpty()) {
            return collect();
        }

        return $this->baseQuery($viewer)
            ->where('listings.user_id', '!=', $viewer->id)
            ->where(function (Builder $query) use ($terms) {
                foreach ($terms as $term) {
                    $query->orWhere(fn (Builder $query) => $query->search($term));
                }
            })
            ->when($coordinates !== null, fn ($query) => $query
                ->nearby($coordinates['latitude'], $coordinates['longitude'], PHP_INT_MAX))
            ->reorder('listings.created_at', 'desc')
            ->limit(self::FOR_YOU_LIMIT)
            ->get();
    }

    private function fromFollowing(User $viewer, ?array $coordinates): Collection
    {
        return $this->baseQuery($viewer)
            ->whereIn('listings.user_id', $viewer->following()->select('users.id'))
            ->where('listings.created_at', '>=', now()->subDays(self::FRESH_DAYS))
            // Any distance: this is only here to show "3.2 km away" on the card.
            ->when($coordinates !== null, fn ($query) => $query
                ->nearby($coordinates['latitude'], $coordinates['longitude'], PHP_INT_MAX))
            ->reorder('listings.created_at', 'desc')
            ->limit(self::FOLLOWING_LIMIT)
            ->get();
    }

    /**
     * Active listings from sellers the viewer can see, loaded the way
     * ListingResource needs them.
     */
    private function baseQuery(User $viewer): Builder
    {
        return Listing::query()->browsableBy($viewer);
    }
}
