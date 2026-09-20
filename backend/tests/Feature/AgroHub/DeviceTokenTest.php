<?php

namespace Tests\Feature\AgroHub;

use App\Models\DeviceToken;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DeviceTokenTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_can_register_a_device_token(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/device-tokens', [
            'token' => 'real-fcm-token-1',
            'platform' => 'android',
        ]);

        $response->assertOk();
        $this->assertDatabaseHas('device_tokens', [
            'user_id' => $user->id,
            'token' => 'real-fcm-token-1',
            'platform' => 'android',
        ]);
    }

    public function test_registering_the_same_token_twice_upserts_rather_than_duplicating(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/device-tokens', ['token' => 'same-token'])->assertOk();
        $this->postJson('/api/v1/device-tokens', ['token' => 'same-token'])->assertOk();

        $this->assertSame(1, DeviceToken::query()->where('token', 'same-token')->count());
    }

    public function test_registering_a_token_previously_owned_by_a_different_user_reassigns_it(): void
    {
        $firstOwner = User::factory()->create();
        DeviceToken::factory()->create(['user_id' => $firstOwner->id, 'token' => 'shared-device-token']);

        $secondUser = User::factory()->create();
        Sanctum::actingAs($secondUser);
        $this->postJson('/api/v1/device-tokens', ['token' => 'shared-device-token'])->assertOk();

        $this->assertDatabaseHas('device_tokens', [
            'token' => 'shared-device-token',
            'user_id' => $secondUser->id,
        ]);
        $this->assertSame(1, DeviceToken::query()->where('token', 'shared-device-token')->count());
    }

    public function test_a_user_can_delete_their_own_device_token(): void
    {
        $user = User::factory()->create();
        DeviceToken::factory()->create(['user_id' => $user->id, 'token' => 'my-token']);
        Sanctum::actingAs($user);

        $this->deleteJson('/api/v1/device-tokens', ['token' => 'my-token'])->assertOk();

        $this->assertDatabaseMissing('device_tokens', ['token' => 'my-token']);
    }

    public function test_a_user_cannot_delete_another_users_device_token(): void
    {
        $owner = User::factory()->create();
        DeviceToken::factory()->create(['user_id' => $owner->id, 'token' => 'someone-elses-token']);

        $intruder = User::factory()->create();
        Sanctum::actingAs($intruder);
        $this->deleteJson('/api/v1/device-tokens', ['token' => 'someone-elses-token'])->assertOk();

        $this->assertDatabaseHas('device_tokens', ['token' => 'someone-elses-token']);
    }
}
