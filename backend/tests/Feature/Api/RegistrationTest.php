<?php

namespace Tests\Feature\Api;

use App\Models\User;
use Tests\TestCase;

class RegistrationTest extends TestCase
{
    public function test_registering_with_a_primary_location_label_saves_it(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Rina Chowdhury',
            'email' => 'rina.chowdhury@example.test',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'latitude' => 23.7461,
            'longitude' => 90.3742,
            'location_label' => 'Dhanmondi, Dhaka',
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.location_label', 'Dhanmondi, Dhaka');
        $this->assertSame(
            'Dhanmondi, Dhaka',
            User::where('email', 'rina.chowdhury@example.test')->value('location_label'),
        );
    }

    public function test_registering_without_a_primary_location_label_still_succeeds(): void
    {
        $response = $this->postJson('/api/v1/auth/register', [
            'name' => 'Tanvir Ahmed',
            'email' => 'tanvir.ahmed@example.test',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'latitude' => 23.8759,
            'longitude' => 90.3795,
        ]);

        $response->assertCreated();
        $this->assertNull(
            User::where('email', 'tanvir.ahmed@example.test')->value('location_label'),
        );
    }
}
