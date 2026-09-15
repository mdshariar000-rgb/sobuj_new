<?php

namespace App\Models;

use App\Enums\SwapOfferStatus;
use Database\Factories\SwapOfferFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class SwapOffer extends Model
{
    /** @use HasFactory<SwapOfferFactory> */
    use HasFactory;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'listing_id',
        'requester_id',
        'status',
        'offer_details',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'status' => SwapOfferStatus::class,
            'offer_details' => 'array',
        ];
    }

    /**
     * @return BelongsTo<Listing, SwapOffer>
     */
    public function listing(): BelongsTo
    {
        return $this->belongsTo(Listing::class);
    }

    /**
     * The user who made this offer.
     *
     * @return BelongsTo<User, SwapOffer>
     */
    public function requester(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requester_id');
    }

    /**
     * @return HasMany<Message>
     */
    public function messages(): HasMany
    {
        return $this->hasMany(Message::class);
    }

    /**
     * The most recent message in this thread (including system events) — used
     * for the conversation-list preview, so it doesn't need to fetch every
     * message just to show the last one.
     *
     * @return HasOne<Message>
     */
    public function latestMessage(): HasOne
    {
        return $this->hasOne(Message::class)->latestOfMany();
    }
}
