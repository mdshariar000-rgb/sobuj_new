<?php

namespace App\Models;

use App\Enums\ListingCondition;
use App\Enums\ListingStatus;
use App\Enums\SwapOfferStatus;
use App\Enums\TransactionType;
use App\Models\Concerns\HasFuzzyLocation;
use Database\Factories\ListingFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Facades\DB;

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
        'quantity',
        'contact',
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
            'transaction_type' => TransactionType::class,
            'status' => ListingStatus::class,
            'condition' => ListingCondition::class,
            'price' => 'decimal:2',
            'quantity' => 'integer',
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
     * @return HasMany<ListingReview>
     */
    public function reviews(): HasMany
    {
        return $this->hasMany(ListingReview::class);
    }

    /**
     * Free-text filter against title/variety/looking_for, for the Discovery search bar.
     * A plain LIKE scan is fine here since it only ever runs against a result set
     * already narrowed by scopeNearby() + status/type filters, not the whole table.
     */
    /**
     * Whether $user may review this listing: only someone who completed a
     * deal for it, so every review comes from a real exchange.
     */
    public function canBeReviewedBy(User $user): bool
    {
        return (int) $this->user_id !== $user->id
            && $this->swapOffers()
                ->where('requester_id', $user->id)
                ->where('status', SwapOfferStatus::Completed)
                ->exists();
    }

    /**
     * Active listings [viewer] may see in feeds and search: not banned, not
     * from anyone blocked either way or suspended — with fuzzy coordinates,
     * the viewer's is_saved flag, photos and owner.
     */
    public function scopeBrowsableBy(Builder $query, User $viewer): Builder
    {
        return $query
            ->where('listings.status', ListingStatus::Active)
            ->whereNull('listings.banned_at')
            ->whereNotIn('listings.user_id', $viewer->hiddenUserIds())
            ->whereHas('user', fn ($query) => $query->where(fn ($query) => $query
                ->where('is_suspended', false)
                ->orWhere('suspended_until', '<', now())))
            ->selectFuzzyCoordinates()
            ->addSelect(['is_saved' => DB::table('saved_listings')
                ->selectRaw('1')
                ->whereColumn('listing_id', 'listings.id')
                ->where('user_id', $viewer->id)
                ->limit(1),
            ])
            ->with(['photos', 'user']);
    }

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
