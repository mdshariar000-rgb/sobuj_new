<?php

namespace Database\Factories;

use App\Models\Group;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * @extends Factory<Group>
 */
class GroupFactory extends Factory
{
    protected $model = Group::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        $name = fake()->unique()->words(3, true);

        return [
            'name' => $name,
            'slug' => Str::slug($name).'-'.fake()->unique()->numberBetween(1, 999999),
            'description' => fake()->sentence(),
            'category' => fake()->randomElement(['Crop Type', 'Region', 'Technique', 'General']),
            'created_by' => User::factory(),
        ];
    }

    /**
     * @return Factory<Group>
     */
    public function private(): Factory
    {
        return $this->state(['visibility' => 'private']);
    }
}
