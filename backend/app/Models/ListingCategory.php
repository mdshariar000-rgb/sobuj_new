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

    /**
     * Renaming a category in the admin panel carries its listings along —
     * otherwise they'd keep the old name and drop out of its filter.
     */
    protected static function booted(): void
    {
        static::updated(function (ListingCategory $category) {
            if ($category->wasChanged('name')) {
                Listing::where('listing_type', $category->getOriginal('name'))
                    ->update(['listing_type' => $category->name]);
            }
        });
    }
}
