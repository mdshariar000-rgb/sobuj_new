<?php

namespace App\Models;

use App\Enums\ListingCondition;
use App\Enums\ListingStatus;
use App\Enums\ListingType;
use App\Enums\TransactionType;
use App\Models\Concerns\HasFuzzyLocation;
use Database\Factories\ListingFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Listing extends Model
{
    /** @use HasFactory<ListingFactory> */
    use HasFactory, HasFuzzyLocation;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'title',
        'variety',
        'description',
        'condition',
        'listing_type',
        'transaction_type',
        'price',
        'status',
        'looking_for',
        'handover_note',
        'is_flagged',
        'flagged_reason',
        'banned_at',
        'banned_reason',
    ];

    /**
     * base_location/fuzzy_location are raw WKB binary — expose coordinates explicitly
     * via getFuzzyCoordinates()/scopeSelectFuzzyCoordinates() instead.
     *
     * @var list<string>
     */
    protected $hidden = [
        'base_location',
        'fuzzy_location',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'listing_type' => ListingType::class,
            'transaction_type' => TransactionType::class,
            'status' => ListingStatus::class,
            'condition' => ListingCondition::class,
            'price' => 'decimal:2',
            'is_flagged' => 'boolean',
            'banned_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<User, Listing>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Swap offers received against this listing.
     *
     * @return HasMany<SwapOffer>
     */
    public function swapOffers(): HasMany
    {
        return $this->hasMany(SwapOffer::class);
    }

    /**
     * @return HasMany<ListingPhoto>
     */
    public function photos(): HasMany
    {
        return $this->hasMany(ListingPhoto::class)->orderBy('sort_order');
    }

    /**
     * @return BelongsToMany<User, Listing>
     */
    public function savedBy(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'saved_listings');
    }

    /**
     * Free-text filter against title/variety/looking_for, for the Discovery search bar.
     * A plain LIKE scan is fine here since it only ever runs against a result set
     * already narrowed by scopeNearby() + status/type filters, not the whole table.
     */
    public function scopeSearch(Builder $query, string $term): Builder
    {
        $like = '%'.str_replace(['%', '_'], ['\\%', '\\_'], $term).'%';

        return $query->where(function (Builder $q) use ($like) {
            $q->where('title', 'like', $like)
                ->orWhere('variety', 'like', $like)
                ->orWhere('looking_for', 'like', $like)
                ->orWhere('description', 'like', $like);
        });
    }
}
