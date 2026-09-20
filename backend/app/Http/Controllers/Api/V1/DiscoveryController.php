<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\ListingStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Listing\NearbyListingsRequest;
use App\Http\Resources\ListingResource;
use App\Models\Listing;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class DiscoveryController extends Controller
{
    private const DEFAULT_RADIUS_KM = 10;

    private const DEFAULT_PER_PAGE = 20;

    /**
     * GET /api/v1/listings/nearby
     *
     * Distance filtering/sorting is delegated to Listing::scopeNearby() (see
     * App\Models\Concerns\HasFuzzyLocation), which builds the
     * ST_Distance_Sphere(fuzzy_location, ST_GeomFromText(...)) comparison against the
     * requester's point, respecting the same long-lat axis-order convention used
     * everywhere else spatial data is written or read in this app. `sort=newest`
     * overrides the scope's default nearest-first ordering.
     */
    public function nearby(NearbyListingsRequest $request): AnonymousResourceCollection
    {
        $data = $request->validated();
        $radiusMeters = (float) ($data['radius_km'] ?? self::DEFAULT_RADIUS_KM) * 1000;

        $query = Listing::query()
            ->where('status', ListingStatus::Active)
            ->whereNotIn('listings.user_id', $request->user()->hiddenUserIds())
            ->when($data['category'] ?? null, fn ($query, $category) => $query->where('listing_type', $category))
            ->when($data['transaction_type'] ?? null, fn ($query, $type) => $query->where('transaction_type', $type))
            ->when($data['q'] ?? null, fn ($query, $term) => $query->search($term))
            ->nearby((float) $data['latitude'], (float) $data['longitude'], $radiusMeters)
            ->selectFuzzyCoordinates()
            // Cheap correlated-subquery boolean rather than eager-loading every
            // listing's full saved-by list — same pattern as PostResource::likes_count.
            ->addSelect(['is_saved' => DB::table('saved_listings')
                ->selectRaw('1')
                ->whereColumn('listing_id', 'listings.id')
                ->where('user_id', $request->user()->id)
                ->limit(1),
            ])
            ->with(['photos', 'user']);

        if (($data['sort'] ?? 'nearest') === 'newest') {
            $query->reorder('created_at', 'desc');
        }

        $listings = $query
            ->paginate($data['per_page'] ?? self::DEFAULT_PER_PAGE)
            ->withQueryString();

        return ListingResource::collection($listings);
    }
}
