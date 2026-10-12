<?php

namespace Tests\Feature\Api;

use App\Enums\ListingStatus;
use App\Models\Listing;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FeedMarketplaceTest extends TestCase
{
    use RefreshDatabase;

    /** Central Leeds. */
    private const LAT = 53.7997;

    private const LNG = -1.5492;

    private function userAt(float $latitude, float $longitude, array $attributes = []): User
    {
        return User::factory()->create([
            'base_location' => User::toPointExpression($latitude, $longitude),
            'fuzzy_location' => User::toPointExpression($latitude, $longitude),
            ...$attributes,
        ]);
    }

    private function listingAt(float $latitude, float $longitude, array $attributes = []): Listing
    {
        return Listing::factory()->create([
            'base_location' => Listing::toPointExpression($latitude, $longitude),
            'fuzzy_location' => Listing::toPointExpression($latitude, $longitude),
            ...$attributes,
        ]);
    }

    private function nearbyIds(): array
    {
        return array_column($this->getJson('/api/v1/feed/marketplace')->assertOk()->json('data.nearby'), 'id');
    }

    public function test_nearby_has_fresh_active_listings_close_to_the_viewer(): void
    {
        $viewer = $this->userAt(self::LAT, self::LNG);
        $close = $this->listingAt(self::LAT + 0.01, self::LNG);
        $farAway = $this->listingAt(51.5072, -0.1276); // London
        $sold = $this->listingAt(self::LAT, self::LNG, ['status' => ListingStatus::Completed]);
        $mine = $this->listingAt(self::LAT, self::LNG, ['user_id' => $viewer->id]);

        Sanctum::actingAs($viewer);
        $ids = $this->nearbyIds();

        $this->assertContains($close->id, $ids);
        $this->assertNotContains($farAway->id, $ids);
        $this->assertNotContains($sold->id, $ids);
        $this->assertNotContains($mine->id, $ids);
    }

    public function test_nearby_leaves_out_saved_listings_and_blocked_sellers(): void
    {
        $viewer = $this->userAt(self::LAT, self::LNG);
        $saved = $this->listingAt(self::LAT, self::LNG);
        $saved->savedBy()->attach($viewer->id);
        $blocked = User::factory()->create();
        $fromBlocked = $this->listingAt(self::LAT, self::LNG, ['user_id' => $blocked->id]);
        $viewer->blockedUsers()->attach($blocked->id);
        $visible = $this->listingAt(self::LAT, self::LNG);

        Sanctum::actingAs($viewer);
        $ids = $this->nearbyIds();

        $this->assertContains($visible->id, $ids);
        $this->assertNotContains($saved->id, $ids);
        $this->assertNotContains($fromBlocked->id, $ids);
    }

    public function test_one_seller_gets_at_most_two_nearby_cards(): void
    {
        $viewer = $this->userAt(self::LAT, self::LNG);
        $seller = User::factory()->create();
        foreach (range(1, 5) as $i) {
            $this->listingAt(self::LAT, self::LNG, ['user_id' => $seller->id]);
        }

        Sanctum::actingAs($viewer);
        $this->assertCount(2, $this->nearbyIds());
    }

    public function test_a_listing_matching_a_growing_interest_ranks_first(): void
    {
        $viewer = $this->userAt(self::LAT, self::LNG, ['growing_interests' => ['Tomatoes']]);
        $this->listingAt(self::LAT, self::LNG, ['title' => 'Mint cuttings']);
        $match = $this->listingAt(self::LAT + 0.05, self::LNG, ['title' => 'Cherry tomatoes seedlings']);

        Sanctum::actingAs($viewer);
        $this->assertSame($match->id, $this->nearbyIds()[0]);
    }

    public function test_from_following_has_new_listings_by_followed_growers_newest_first(): void
    {
        $viewer = $this->userAt(self::LAT, self::LNG);
        $followed = User::factory()->create();
        $viewer->following()->attach($followed->id, ['created_at' => now()]);
        $older = $this->listingAt(51.5072, -0.1276, ['user_id' => $followed->id]);
        $older->forceFill(['created_at' => now()->subDays(2)])->save();
        $newer = $this->listingAt(self::LAT, self::LNG, ['user_id' => $followed->id]);
        $stale = $this->listingAt(self::LAT, self::LNG, ['user_id' => $followed->id]);
        $stale->forceFill(['created_at' => now()->subDays(30)])->save();
        $stranger = $this->listingAt(self::LAT, self::LNG);

        Sanctum::actingAs($viewer);
        $response = $this->getJson('/api/v1/feed/marketplace')->assertOk();

        // Any distance counts for followed growers (the London one is included).
        $this->assertSame([$newer->id, $older->id], array_column($response->json('data.from_following'), 'id'));
        $this->assertSame($followed->id, $response->json('data.from_following.0.owner.id'));
        // Shown once: a followed grower's listing isn't repeated in the carousel.
        $nearby = array_column($response->json('data.nearby'), 'id');
        $this->assertNotContains($newer->id, $nearby);
        $this->assertContains($stranger->id, $nearby);
    }
}
