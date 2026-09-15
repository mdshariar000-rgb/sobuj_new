<?php

namespace Database\Factories;

use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * @extends Factory<User>
 */
class UserFactory extends Factory
{
    /**
     * The current password being used by the factory.
     */
    protected static ?string $password;

    /**
     * Define the model's default state.
     *
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        // Dhaka-ish bounding box. base_location/fuzzy_location are NOT NULL (required
        // by the SPATIAL index — see the users migration), so every factory-made user
        // needs a real point; toPointExpression() is HasFuzzyLocation's public helper
        // for building the raw ST_GeomFromText(...) expression Eloquent will insert.
        $latitude = fake()->latitude(23.70, 23.90);
        $longitude = fake()->longitude(90.30, 90.50);

        return [
            'name' => fake()->name(),
            'email' => fake()->unique()->safeEmail(),
            'email_verified_at' => now(),
            'password' => static::$password ??= Hash::make('password'),
            'remember_token' => Str::random(10),
            'base_location' => User::toPointExpression($latitude, $longitude),
            'fuzzy_location' => User::toPointExpression($latitude, $longitude),
        ];
    }

    /**
     * Indicate that the model's email address should be unverified.
     */
    public function unverified(): static
    {
        return $this->state(fn (array $attributes) => [
            'email_verified_at' => null,
        ]);
    }
}
