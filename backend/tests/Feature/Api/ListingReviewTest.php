<?php

namespace Tests\Feature\Api;

use App\Enums\NotificationType;
use App\Enums\SwapOfferStatus;
use App\Models\AppNotification;
use App\Models\Listing;
use App\Models\ListingReview;
use App\Models\SwapOffer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ListingReviewTest extends TestCase
{
    use RefreshDatabase;

    /** Only someone who completed a deal for a listing may review it. */
    private function completedDeal(Listing $listing, User $buyer): void
    {
        SwapOffer::factory()->create([
            'listing_id' => $listing->id,
            'requester_id' => $buyer->id,
            'status' => SwapOfferStatus::Completed,
        ]);
    }

    public function test_reviewing_needs_a_completed_deal_for_the_listing(): void
    {
        $listing = Listing::factory()->create();
        $reviewer = User::factory()->create();
        SwapOffer::factory()->create([
            'listing_id' => $listing->id,
            'requester_id' => $reviewer->id,
            'status' => SwapOfferStatus::Accepted,
        ]);
        Sanctum::actingAs($reviewer);

        $this->getJson("/api/v1/listings/{$listing->id}")->assertJsonPath('data.can_review', false);
        $this->postJson("/api/v1/listings/{$listing->id}/reviews", ['rating' => 5])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('listing');

        $this->completedDeal($listing, $reviewer);

        $this->getJson("/api/v1/listings/{$listing->id}")->assertJsonPath('data.can_review', true);
        $this->postJson("/api/v1/listings/{$listing->id}/reviews", ['rating' => 5])->assertCreated();
    }

    public function test_a_user_can_review_a_listing_with_a_rating_and_comment(): void
    {
        $owner = User::factory()->create();
        $listing = Listing::factory()->for($owner)->create();
        $reviewer = User::factory()->create();
        $this->completedDeal($listing, $reviewer);
        Sanctum::actingAs($reviewer);

        $response = $this->postJson("/api/v1/listings/{$listing->id}/reviews", [
            'rating' => 4,
            'comment' => 'Healthy cuttings, great packaging.',
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.rating', 4);
        $response->assertJsonPath('data.comment', 'Healthy cuttings, great packaging.');
        $response->assertJsonPath('data.reviewer.id', $reviewer->id);

        $this->assertDatabaseHas('listing_reviews', [
            'listing_id' => $listing->id,
            'reviewer_id' => $reviewer->id,
            'rating' => 4,
        ]);
    }

    public function test_reviewing_again_updates_the_existing_review_instead_of_creating_a_second_one(): void
    {
        $owner = User::factory()->create();
        $listing = Listing::factory()->for($owner)->create();
        $reviewer = User::factory()->create();
        $this->completedDeal($listing, $reviewer);
        Sanctum::actingAs($reviewer);

        $this->postJson("/api/v1/listings/{$listing->id}/reviews", ['rating' => 3])
            ->assertCreated();

        $response = $this->postJson("/api/v1/listings/{$listing->id}/reviews", [
            'rating' => 5,
            'comment' => 'Updating my review after a second order.',
        ]);

        $response->assertOk();
        $response->assertJsonPath('data.rating', 5);
        $this->assertSame(1, ListingReview::query()->where('listing_id', $listing->id)->count());
    }

    public function test_rating_must_be_between_one_and_five(): void
    {
        $listing = Listing::factory()->create();
        $reviewer = User::factory()->create();
        Sanctum::actingAs($reviewer);

        $this->postJson("/api/v1/listings/{$listing->id}/reviews", ['rating' => 0])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('rating');

        $this->postJson("/api/v1/listings/{$listing->id}/reviews", ['rating' => 6])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('rating');
    }

    public function test_you_cannot_review_your_own_listing(): void
    {
        $owner = User::factory()->create();
        $listing = Listing::factory()->for($owner)->create();
        Sanctum::actingAs($owner);

        $this->postJson("/api/v1/listings/{$listing->id}/reviews", ['rating' => 5])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('listing');
    }

    public function test_you_cannot_review_a_blocked_sellers_listing(): void
    {
        $owner = User::factory()->create();
        $listing = Listing::factory()->for($owner)->create();
        $reviewer = User::factory()->create();
        Sanctum::actingAs($reviewer);
        $this->postJson("/api/v1/users/{$owner->id}/block")->assertOk();

        $this->postJson("/api/v1/listings/{$listing->id}/reviews", ['rating' => 5])
            ->assertNotFound();
    }

    public function test_reviewing_a_listing_notifies_its_owner_only_on_the_first_review(): void
    {
        $owner = User::factory()->create();
        $listing = Listing::factory()->for($owner)->create();
        $reviewer = User::factory()->create();
        $this->completedDeal($listing, $reviewer);
        Sanctum::actingAs($reviewer);

        $this->postJson("/api/v1/listings/{$listing->id}/reviews", ['rating' => 4])->assertCreated();

        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $owner->id,
            'actor_id' => $reviewer->id,
            'type' => NotificationType::ListingReviewed->value,
        ]);

        $this->postJson("/api/v1/listings/{$listing->id}/reviews", ['rating' => 5])->assertOk();

        $this->assertSame(1, AppNotification::query()->count());
    }

    public function test_reviews_list_excludes_blocked_users_and_show_includes_rating_summary(): void
    {
        $owner = User::factory()->create();
        $listing = Listing::factory()->for($owner)->create();
        $reviewer1 = User::factory()->create();
        $reviewer2 = User::factory()->create();
        $this->completedDeal($listing, $reviewer1);
        $this->completedDeal($listing, $reviewer2);

        Sanctum::actingAs($reviewer1);
        $this->postJson("/api/v1/listings/{$listing->id}/reviews", ['rating' => 2])->assertCreated();
        Sanctum::actingAs($reviewer2);
        $this->postJson("/api/v1/listings/{$listing->id}/reviews", ['rating' => 4])->assertCreated();

        Sanctum::actingAs($owner);
        $this->postJson("/api/v1/users/{$reviewer2->id}/block")->assertOk();

        $reviewerIds = collect(
            $this->getJson("/api/v1/listings/{$listing->id}/reviews")->assertOk()->json('data'),
        )->pluck('reviewer.id');
        $this->assertEqualsCanonicalizing([$reviewer1->id], $reviewerIds->all());

        $show = $this->getJson("/api/v1/listings/{$listing->id}")->assertOk();
        $show->assertJsonPath('data.reviews_count', 2);
        $show->assertJsonPath('data.average_rating', 3.0);
    }

    public function test_a_review_can_be_deleted_by_its_author_or_the_listing_owner(): void
    {
        $owner = User::factory()->create();
        $listing = Listing::factory()->for($owner)->create();
        $reviewer = User::factory()->create();
        $stranger = User::factory()->create();
        $this->completedDeal($listing, $reviewer);

        Sanctum::actingAs($reviewer);
        $review = $this->postJson("/api/v1/listings/{$listing->id}/reviews", ['rating' => 1])
            ->assertCreated()
            ->json('data');

        Sanctum::actingAs($stranger);
        $this->deleteJson("/api/v1/listings/{$listing->id}/reviews/{$review['id']}")
            ->assertForbidden();

        Sanctum::actingAs($owner);
        $this->deleteJson("/api/v1/listings/{$listing->id}/reviews/{$review['id']}")->assertOk();

        $this->assertDatabaseMissing('listing_reviews', ['id' => $review['id']]);
    }
}
