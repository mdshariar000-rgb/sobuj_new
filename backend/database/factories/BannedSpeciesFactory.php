<?php

namespace Database\Factories;

use App\Models\BannedSpecies;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<BannedSpecies>
 */
class BannedSpeciesFactory extends Factory
{
    protected $model = BannedSpecies::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'name' => fake()->unique()->words(2, true),
            'notes' => fake()->sentence(),
        ];
    }
}
