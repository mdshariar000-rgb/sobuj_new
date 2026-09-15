<?php

namespace Tests\Feature\Filament;

use App\Filament\Pages\ManageSettings;
use App\Models\Setting;
use App\Models\User;
use App\Services\StripePriceService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class ManageSettingsTest extends TestCase
{
    use RefreshDatabase;

    public function test_non_admin_cannot_access_the_settings_page(): void
    {
        $user = User::factory()->create(['is_admin' => false]);

        $this->actingAs($user)
            ->get(ManageSettings::getUrl())
            ->assertForbidden();
    }

    public function test_admin_can_access_the_settings_page(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);

        $this->actingAs($admin)
            ->get(ManageSettings::getUrl())
            ->assertSuccessful();
    }

    public function test_the_form_never_prefills_the_real_key(): void
    {
        Setting::set('gemini_api_key', 'AIzaSy-existing-secret');
        $admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($admin);

        Livewire::test(ManageSettings::class)
            ->assertFormSet(['gemini_api_key' => '']);
    }

    public function test_submitting_a_key_saves_it(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($admin);

        Livewire::test(ManageSettings::class)
            ->fillForm(['gemini_api_key' => 'AIzaSy-new-secret'])
            ->call('save')
            ->assertHasNoFormErrors();

        $this->assertSame('AIzaSy-new-secret', Setting::get('gemini_api_key'));
    }

    public function test_submitting_a_blank_value_keeps_the_existing_key(): void
    {
        Setting::set('gemini_api_key', 'AIzaSy-existing-secret');
        $admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($admin);

        Livewire::test(ManageSettings::class)
            ->fillForm(['gemini_api_key' => ''])
            ->call('save')
            ->assertHasNoFormErrors();

        $this->assertSame('AIzaSy-existing-secret', Setting::get('gemini_api_key'));
    }

    public function test_stripe_secret_fields_never_prefill_but_prices_do(): void
    {
        Setting::set('stripe_secret_key', 'sk_test_existing');
        Setting::set('stripe_monthly_price_usd', '12.99');
        $admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($admin);

        Livewire::test(ManageSettings::class)
            ->assertFormSet([
                'stripe_secret_key' => '',
                'stripe_monthly_price_usd' => 12.99,
            ]);
    }

    public function test_submitting_settings_without_changing_the_price_never_calls_stripe(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($admin);

        // No StripePriceService mock bound — if save() called it anyway
        // (e.g. because the price fields weren't genuinely changed), this
        // would throw trying to reach the real Stripe API with no key
        // configured, failing the test.
        Livewire::test(ManageSettings::class)
            ->fillForm([
                'stripe_publishable_key' => 'pk_test_abc',
                'stripe_secret_key' => 'sk_test_abc',
                'stripe_webhook_secret' => 'whsec_abc',
            ])
            ->call('save')
            ->assertHasNoFormErrors();

        $this->assertSame('pk_test_abc', Setting::get('stripe_publishable_key'));
        $this->assertSame('sk_test_abc', Setting::get('stripe_secret_key'));
        $this->assertSame('whsec_abc', Setting::get('stripe_webhook_secret'));
        $this->assertNull(Setting::get('stripe_price_id_monthly'));
    }

    public function test_changing_a_price_creates_a_new_stripe_price_and_stores_its_id(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($admin);

        $this->mock(StripePriceService::class, function ($mock) {
            $mock->shouldReceive('updatePrice')
                ->once()
                ->with('month', 12.99)
                ->andReturn('price_new_monthly_123');
        });

        Livewire::test(ManageSettings::class)
            ->fillForm(['stripe_monthly_price_usd' => 12.99])
            ->call('save')
            ->assertHasNoFormErrors();

        $this->assertSame('price_new_monthly_123', Setting::get('stripe_price_id_monthly'));
        $this->assertSame('12.99', Setting::get('stripe_monthly_price_usd'));
    }
}
