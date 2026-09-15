<?php

namespace Database\Factories;

use App\Enums\SwapOfferStatus;
use App\Models\Listing;
use App\Models\SwapOffer;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<SwapOffer>
 */
class SwapOfferFactory extends Factory
{
    protected $model = SwapOffer::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'listing_id' => Listing::factory(),
            'requester_id' => User::factory(),
            'status' => SwapOfferStatus::Pending,
            'offer_details' => null,
        ];
    }
}
