<?php

namespace Tests\Feature\Filament;

use App\Filament\Resources\SubscriptionResource\Pages\ListSubscriptions;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class SubscriptionResourceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->actingAs(User::factory()->create(['is_admin' => true]));
    }

    public function test_index_page_lists_real_subscribers(): void
    {
        Setting::set('stripe_price_id_monthly', 'price_monthly_abc');

        $subscriber = User::factory()->create();
        $subscription = $subscriber->subscriptions()->create([
            'type' => 'default',
            'stripe_id' => 'sub_test_123',
            'stripe_status' => 'active',
            'stripe_price' => 'price_monthly_abc',
            'quantity' => 1,
        ]);

        Livewire::test(ListSubscriptions::class)
            ->assertSuccessful()
            ->assertCanSeeTableRecords([$subscription]);
    }
}
