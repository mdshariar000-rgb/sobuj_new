<?php

namespace App\Policies;

use App\Models\Listing;
use App\Models\User;

class ListingPolicy
{
    /**
     * Staff moderating listings through the Filament admin panel (ListingResource)
     * bypass the ownership checks below entirely — those checks exist for the mobile
     * API, where only a listing's own owner may edit/delete it. Returning null (rather
     * than a bool) for a non-admin lets the specific ability method decide as normal.
     */
    public function before(User $user, string $ability): ?bool
    {
        return $user->is_admin ? true : null;
    }

    public function update(User $user, Listing $listing): bool
    {
        return $user->id === $listing->user_id;
    }

    public function delete(User $user, Listing $listing): bool
    {
        return $user->id === $listing->user_id;
    }
}
