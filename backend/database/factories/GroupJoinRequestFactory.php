<?php

namespace Database\Factories;

use App\Models\Group;
use App\Models\GroupJoinRequest;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<GroupJoinRequest>
 */
class GroupJoinRequestFactory extends Factory
{
    protected $model = GroupJoinRequest::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'group_id' => Group::factory(),
            'user_id' => User::factory(),
            'status' => 'pending',
            'requested_at' => now(),
        ];
    }
}
