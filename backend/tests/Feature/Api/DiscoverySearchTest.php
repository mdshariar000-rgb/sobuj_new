<?php

namespace Tests\Feature\Api;

use App\Enums\ListingStatus;
use App\Models\Listing;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DiscoverySearchTest extends TestCase
{
    use RefreshDatabase;

    public function test_q_filters_by_title_variety_or_looking_for(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $tomato = Listing::factory()->create([
            'title' => 'Cherry Tomato Seeds',
            'variety' => 'Sweet 100',
            'looking_for' => 'Basil cuttings',
            'status' => ListingStatus::Active,
        ]);
        $tomato->setLocation(23.780636, 90.279785)->save();

        $basil = Listing::factory()->create([
            'title' => 'Fresh Basil Cuttings',
            'variety' => 'Genovese',
            'looking_for' => 'Anything green',
            'status' => ListingStatus::Active,
        ]);
        $basil->setLocation(23.781, 90.280)->save();

        $fern = Listing::factory()->create([
            'title' => 'Boston Fern',
            'variety' => null,
            'looking_for' => 'Succulents',
            'status' => ListingStatus::Active,
        ]);
        $fern->setLocation(23.782, 90.281)->save();

        $response = $this->getJson('/api/v1/listings/nearby?'.http_build_query([
            'latitude' => 23.780636,
            'longitude' => 90.279785,
            'radius_km' => 50,
            'q' => 'basil',
        ]));

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id')->all();

        // Matches the tomato listing (looking_for contains "basil") and the basil
        // listing itself (title/variety), but not the unrelated fern.
        $this->assertContains($tomato->id, $ids);
        $this->assertContains($basil->id, $ids);
        $this->assertNotContains($fern->id, $ids);
    }

    public function test_percent_and_underscore_in_query_are_treated_literally(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $organic = Listing::factory()->create(['title' => '100% Organic Seeds', 'status' => ListingStatus::Active]);
        $organic->setLocation(23.780636, 90.279785)->save();

        $unrelated = Listing::factory()->create(['title' => 'Totally Unrelated Plant', 'status' => ListingStatus::Active]);
        $unrelated->setLocation(23.781, 90.280)->save();

        $response = $this->getJson('/api/v1/listings/nearby?'.http_build_query([
            'latitude' => 23.780636,
            'longitude' => 90.279785,
            'radius_km' => 50,
            'q' => '100%',
        ]));

        $response->assertOk();
        $titles = collect($response->json('data'))->pluck('title')->all();

        $this->assertSame(['100% Organic Seeds'], $titles);
    }
}
