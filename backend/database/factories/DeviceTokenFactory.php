<?php

namespace Database\Factories;

use App\Models\DeviceToken;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<DeviceToken>
 */
class DeviceTokenFactory extends Factory
{
    protected $model = DeviceToken::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'token' => fake()->unique()->uuid(),
            'platform' => 'android',
            'device_id' => fake()->uuid(),
            'app_version' => '1.0.0+36',
            'last_used_at' => now(),
        ];
    }
}
