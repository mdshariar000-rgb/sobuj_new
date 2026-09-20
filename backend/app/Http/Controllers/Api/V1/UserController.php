<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\ListingStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\ListingResource;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\Request;
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

    public function show(Request $request, User $user): UserResource
    {
        abort_if($request->user()->hasBlockRelationWith($user), 404);

        return new UserResource($user);
    }

    public function listings(Request $request, User $user): AnonymousResourceCollection
    {
        abort_if($request->user()->hasBlockRelationWith($user), 404);

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
