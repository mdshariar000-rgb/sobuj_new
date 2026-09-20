<?php

namespace Database\Factories;

use App\Enums\ListingStatus;
use App\Enums\TransactionType;
use App\Models\Listing;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Listing>
 */
class ListingFactory extends Factory
{
    protected $model = Listing::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $latitude = fake()->latitude(23.70, 23.90);
        $longitude = fake()->longitude(90.30, 90.50);

        return [
            'user_id' => User::factory(),
            'title' => fake()->words(3, true),
            'variety' => fake()->word(),
            'listing_type' => fake()->randomElement([
                'Seeds & Scions',
                'Live Plants & Saplings',
                'Organic Fertilizers',
                'Farm Tools & Equipment',
                'Harvest & Produce',
                'Compost & Soils',
            ]),
            'transaction_type' => TransactionType::Swap,
            'price' => null,
            'status' => ListingStatus::Active,
            'looking_for' => fake()->sentence(),
            'base_location' => Listing::toPointExpression($latitude, $longitude),
            'fuzzy_location' => Listing::toPointExpression($latitude, $longitude),
        ];
    }
}
