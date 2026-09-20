<?php

namespace Database\Factories;

use App\Enums\NotificationType;
use App\Models\AppNotification;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<AppNotification>
 */
class AppNotificationFactory extends Factory
{
    protected $model = AppNotification::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'recipient_id' => User::factory(),
            'actor_id' => User::factory(),
            'type' => fake()->randomElement(NotificationType::cases()),
            'title' => fake()->sentence(4),
            'body' => fake()->sentence(10),
            'data' => ['post_id' => fake()->numberBetween(1, 1000)],
            'read_at' => null,
        ];
    }

    public function read(): self
    {
        return $this->state(['read_at' => now()]);
    }
}
