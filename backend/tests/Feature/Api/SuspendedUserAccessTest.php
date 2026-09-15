<?php

namespace Tests\Feature\Api;

use App\Models\Listing;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SuspendedUserAccessTest extends TestCase
{
    use RefreshDatabase;

    public function test_login_rejects_a_suspended_account_with_403_and_the_reason(): void
    {
        User::factory()->create([
            'email' => 'suspended@example.com',
            'password' => 'password123',
            'is_suspended' => true,
            'suspension_reason' => 'Repeated banned-species listings',
        ]);

        $response = $this->postJson('/api/v1/auth/login', [
            'email' => 'suspended@example.com',
            'password' => 'password123',
        ]);

        $response->assertForbidden();
        $response->assertJsonFragment(['message' => 'This account has been suspended: Repeated banned-species listings']);
    }

    public function test_a_suspended_users_existing_token_is_blocked_from_protected_routes(): void
    {
        $user = User::factory()->create(['is_suspended' => false]);
        Sanctum::actingAs($user);

        // Confirm the token works before suspension.
        $this->getJson('/api/v1/listings/nearby?latitude=23.78&longitude=90.27')->assertOk();

        $user->update(['is_suspended' => true]);

        $this->getJson('/api/v1/listings/nearby?latitude=23.78&longitude=90.27')->assertForbidden();
    }

    public function test_a_suspended_user_can_still_call_me_and_logout(): void
    {
        $user = User::factory()->create(['is_suspended' => true, 'suspension_reason' => 'Spam']);
        Sanctum::actingAs($user);

        $me = $this->getJson('/api/v1/auth/me');
        $me->assertOk();
        $me->assertJsonPath('data.is_suspended', true);
        $me->assertJsonPath('data.suspension_reason', 'Spam');

        $this->postJson('/api/v1/auth/logout')->assertOk();
    }

    public function test_me_hides_moderation_fields_when_not_self(): void
    {
        // UserResource only reveals is_suspended/suspension_reason/email for the
        // account's own owner — regression guard against a future refactor
        // accidentally leaking it into e.g. a listing's embedded owner resource.
        $viewer = User::factory()->create();
        $other = User::factory()->create(['is_suspended' => true, 'suspension_reason' => 'Spam']);

        Sanctum::actingAs($viewer);

        $response = $this->getJson("/api/v1/listings/{$this->makeListingFor($other)->id}");

        $response->assertOk();
        $response->assertJsonMissingPath('data.owner.is_suspended');
        $response->assertJsonMissingPath('data.owner.suspension_reason');
        $response->assertJsonMissingPath('data.owner.email');
    }

    private function makeListingFor(User $user): Listing
    {
        return Listing::factory()->create(['user_id' => $user->id]);
    }
}
