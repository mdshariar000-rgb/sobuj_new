<?php

namespace Database\Factories;

use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<GroupMessage>
 */
class GroupMessageFactory extends Factory
{
    protected $model = GroupMessage::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'group_id' => Group::factory(),
            'body' => fake()->sentence(),
            'image_path' => null,
        ];
    }

    public function configure(): static
    {
        return $this->afterMaking(function (GroupMessage $message) {
            $message->sender_id ??= User::factory()->create()->id;
        });
    }
}
