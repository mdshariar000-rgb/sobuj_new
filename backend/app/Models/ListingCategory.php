<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * An admin-managed marketplace listing category — the mobile app's "create a
 * listing" form picks from this list rather than typing free text, and
 * StoreListingRequest/UpdateListingRequest/NearbyListingsRequest validate
 * against it by name (not a foreign key on listings.listing_type, so existing
 * listings keep whatever category they already had even if it's later
 * removed from this list).
 */
class ListingCategory extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'name',
    ];
}
