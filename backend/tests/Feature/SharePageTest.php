<?php

namespace Tests\Feature;

use App\Enums\ListingStatus;
use App\Models\Listing;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SharePageTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_live_listing_page_shows_the_listing_and_download_links(): void
    {
        Setting::set('app_store_url', 'https://apps.apple.com/app/id6818218536');
        Setting::set('android_download_url', 'https://example.com/shobuj.apk');
        $listing = Listing::factory()->create([
            'title' => 'Snake plant pups',
            'status' => ListingStatus::Active,
            'contact' => '07700 900123',
        ]);

        $this->get("/l/{$listing->id}")
            ->assertOk()
            ->assertSee('Snake plant pups')
            ->assertSee('https://apps.apple.com/app/id6818218536', false)
            ->assertSee('https://example.com/shobuj.apk', false)
            ->assertDontSee('07700 900123');
    }

    public function test_a_closed_or_missing_listing_shows_the_fallback(): void
    {
        $sold = Listing::factory()->create([
            'title' => 'Sold basil',
            'status' => ListingStatus::Completed,
        ]);

        $this->get("/l/{$sold->id}")
            ->assertOk()
            ->assertDontSee('Sold basil')
            ->assertSee('This listing is no longer available.');
        $this->get('/l/999999')->assertOk()->assertSee('This listing is no longer available.');
    }

    public function test_a_profile_page_shows_the_name_but_not_a_suspended_account(): void
    {
        $user = User::factory()->create(['name' => 'Maya Green']);
        $suspended = User::factory()->create(['name' => 'Hidden Person', 'is_suspended' => true]);

        $this->get("/u/{$user->id}")->assertOk()->assertSee('Maya Green');
        $this->get("/u/{$suspended->id}")
            ->assertOk()
            ->assertDontSee('Hidden Person')
            ->assertSee('This profile is no longer available.');
    }

    public function test_download_buttons_are_hidden_until_links_are_set(): void
    {
        $listing = Listing::factory()->create(['status' => ListingStatus::Active]);

        $this->get("/l/{$listing->id}")
            ->assertOk()
            ->assertDontSee('Get it for iPhone')
            ->assertDontSee('Get it for Android');
    }
}
