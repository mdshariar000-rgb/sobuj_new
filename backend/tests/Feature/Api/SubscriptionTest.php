<?php

namespace Tests\Feature\Api;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Covers GET /subscriptions/me only — POST /subscriptions and
 * DELETE /subscriptions/me both make a real Stripe API call via Cashier
 * (creating/canceling a real subscription), so they're verified live against
 * Stripe's test mode instead of mocked here, matching this app's existing
 * pattern of verifying third-party-API-backed writes for real rather than
 * stubbing them out.
 */
class SubscriptionTest extends TestCase
{
    use RefreshDatabase;

    public function test_an_unsubscribed_user_has_no_access(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/subscriptions/me');

        $response->assertOk();
        $response->assertJsonPath('data.has_access', false);
        $response->assertJsonPath('data.status', null);
    }

    public function test_a_trialing_subscription_grants_access(): void
    {
        $user = User::factory()->create();
        $trialEndsAt = now()->addDays(7);

        $user->subscriptions()->create([
            'type' => 'default',
            'stripe_id' => 'sub_test_'.Str::random(16),
            'stripe_status' => 'trialing',
            'stripe_price' => 'price_test_monthly',
            'quantity' => 1,
            'trial_ends_at' => $trialEndsAt,
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/v1/subscriptions/me');

        $response->assertOk();
        $response->assertJsonPath('data.has_access', true);
        $response->assertJsonPath('data.status', 'trialing');
        $response->assertJsonPath('data.on_trial', true);
    }

    public function test_a_canceled_subscription_reports_no_access(): void
    {
        $user = User::factory()->create();

        $user->subscriptions()->create([
            'type' => 'default',
            'stripe_id' => 'sub_test_'.Str::random(16),
            'stripe_status' => 'canceled',
            'stripe_price' => 'price_test_monthly',
            'quantity' => 1,
            'ends_at' => now()->subDay(),
        ]);

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/v1/subscriptions/me');

        $response->assertOk();
        $response->assertJsonPath('data.has_access', false);
    }
}
