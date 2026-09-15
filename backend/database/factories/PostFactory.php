<?php

namespace Database\Factories;

use App\Models\Post;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Post>
 */
class PostFactory extends Factory
{
    protected $model = Post::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'author_id' => User::factory(),
            // Defaults to a general Home Feed post (no group). Override with
            // ->for($group) or ->state(['group_id' => $group->id]) for a
            // group discussion post.
            'group_id' => null,
            'body' => fake()->paragraph(),
            'image_path' => null,
        ];
    }
}
