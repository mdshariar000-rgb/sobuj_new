<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\ListingStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\ListingResource;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

/**
 * A grower's public profile — reached from "View Seller Profile" on a
 * listing card. Only ever exposes what UserResource already treats as
 * public (name, verification, growing setup/experience, rating) plus their
 * active listings; never email/suspension state.
 */
class UserController extends Controller
{
    private const PER_PAGE = 20;

    public function show(User $user): UserResource
    {
        return new UserResource($user);
    }

    public function listings(User $user): AnonymousResourceCollection
    {
        $listings = $user->listings()
            ->where('status', ListingStatus::Active)
            ->selectFuzzyCoordinates()
            ->with('photos')
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return ListingResource::collection($listings);
    }
}
