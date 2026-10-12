<?php

namespace Tests\Feature\Api;

use App\Enums\ListingStatus;
use App\Enums\SwapOfferStatus;
use App\Models\Listing;
use App\Models\ListingReview;
use App\Models\Post;
use App\Models\SwapOffer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PublicProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_profile_has_post_and_listing_counts_and_trust_signals(): void
    {
        $grower = User::factory()->create();
        Post::factory()->count(2)->create(['author_id' => $grower->id]);
        $listing = Listing::factory()->for($grower)->create();
        Listing::factory()->for($grower)->create(['status' => ListingStatus::Completed]);

        $buyerA = User::factory()->create();
        $buyerB = User::factory()->create();
        foreach ([[$buyerA, 5], [$buyerB, 4]] as [$buyer, $rating]) {
            SwapOffer::factory()->create([
                'listing_id' => $listing->id,
                'requester_id' => $buyer->id,
                'status' => SwapOfferStatus::Completed,
            ]);
            ListingReview::query()->forceCreate([
                'listing_id' => $listing->id,
                'reviewer_id' => $buyer->id,
                'rating' => $rating,
            ]);
        }
        // A deal they completed as the buyer counts too; an open one doesn't.
        SwapOffer::factory()->create(['requester_id' => $grower->id, 'status' => SwapOfferStatus::Completed]);
        SwapOffer::factory()->create(['requester_id' => $grower->id, 'status' => SwapOfferStatus::Pending]);

        Sanctum::actingAs(User::factory()->create());
        $this->getJson("/api/v1/users/{$grower->id}")
            ->assertOk()
            ->assertJsonPath('data.posts_count', 2)
            ->assertJsonPath('data.active_listings_count', 1)
            ->assertJsonPath('data.seller_rating', 4.5)
            ->assertJsonPath('data.seller_reviews_count', 2)
            ->assertJsonPath('data.completed_deals_count', 3);
    }

    public function test_a_new_grower_has_no_rating(): void
    {
        $grower = User::factory()->create();

        Sanctum::actingAs(User::factory()->create());
        $this->getJson("/api/v1/users/{$grower->id}")
            ->assertOk()
            ->assertJsonPath('data.seller_rating', null)
            ->assertJsonPath('data.seller_reviews_count', 0)
            ->assertJsonPath('data.completed_deals_count', 0);
    }
}
