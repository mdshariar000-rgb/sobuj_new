<?php

namespace Database\Factories;

use App\Enums\EventFormat;
use App\Enums\EventStatus;
use App\Models\Event;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Event>
 */
class EventFactory extends Factory
{
    protected $model = Event::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $startsAt = fake()->dateTimeBetween('+1 day', '+2 months');

        return [
            'host_id' => User::factory(),
            'group_id' => null,
            'title' => fake()->sentence(4),
            'description' => fake()->paragraph(),
            'format' => fake()->randomElement(EventFormat::cases()),
            'location' => fake()->address(),
            'starts_at' => $startsAt,
            'ends_at' => (clone $startsAt)->modify('+2 hours'),
            'capacity' => fake()->optional()->numberBetween(5, 200),
            'status' => EventStatus::Published,
        ];
    }
}
