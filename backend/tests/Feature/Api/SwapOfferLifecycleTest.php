<?php

namespace Tests\Feature\Api;

use App\Enums\ListingStatus;
use App\Enums\NotificationType;
use App\Enums\SwapOfferStatus;
use App\Models\AppNotification;
use App\Models\Listing;
use App\Models\SwapOffer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SwapOfferLifecycleTest extends TestCase
{
    use RefreshDatabase;

    private User $seller;

    private Listing $listing;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seller = User::factory()->create();
        $this->listing = Listing::factory()->for($this->seller)->create(['title' => 'Chilli plants']);
    }

    private function offerFrom(User $buyer): int
    {
        Sanctum::actingAs($buyer);

        return $this->postJson("/api/v1/listings/{$this->listing->id}/swap-offers", [
            'offer_details' => ['note' => 'Can I collect Saturday?'],
        ])->assertCreated()->json('data.id');
    }

    private function setStatus(User $as, int $offerId, SwapOfferStatus $status)
    {
        Sanctum::actingAs($as);

        return $this->patchJson("/api/v1/swap-offers/{$offerId}/status", ['status' => $status->value]);
    }

    private function listingStatus(): ListingStatus
    {
        return $this->listing->fresh()->status;
    }

    public function test_a_multi_unit_listing_stays_on_sale_until_its_quantity_runs_out(): void
    {
        $this->listing->update(['quantity' => 10]);
        $first = User::factory()->create();
        $second = User::factory()->create();
        $firstOffer = $this->offerFrom($first);
        $secondOffer = $this->offerFrom($second);

        // Accepting doesn't reserve a listing that has more than one unit.
        $this->setStatus($this->seller, $firstOffer, SwapOfferStatus::Accepted)->assertOk();
        $this->assertSame(ListingStatus::Active, $this->listingStatus());

        // The seller says this deal took 3 — 7 left, still on sale, other offers untouched.
        Sanctum::actingAs($this->seller);
        $this->patchJson("/api/v1/swap-offers/{$firstOffer}/status", [
            'status' => SwapOfferStatus::Completed->value,
            'quantity_sold' => 3,
        ])->assertOk();
        $this->assertSame(7, $this->listing->fresh()->quantity);
        $this->assertSame(ListingStatus::Active, $this->listingStatus());
        $this->assertSame(SwapOfferStatus::Pending, SwapOffer::find($secondOffer)->status);
        $this->assertDatabaseHas('messages', ['swap_offer_id' => $firstOffer, 'body' => '3 sold — 7 still available.']);

        // Selling the last 7 closes the listing.
        $this->setStatus($this->seller, $secondOffer, SwapOfferStatus::Accepted)->assertOk();
        Sanctum::actingAs($this->seller);
        $this->patchJson("/api/v1/swap-offers/{$secondOffer}/status", [
            'status' => SwapOfferStatus::Completed->value,
            'quantity_sold' => 7,
        ])->assertOk();
        $this->assertSame(0, $this->listing->fresh()->quantity);
        $this->assertSame(ListingStatus::Completed, $this->listingStatus());
    }

    public function test_a_buyer_marking_a_multi_unit_deal_done_counts_as_one_whatever_they_send(): void
    {
        $this->listing->update(['quantity' => 5]);
        $buyer = User::factory()->create();
        $offerId = $this->offerFrom($buyer);
        $this->setStatus($this->seller, $offerId, SwapOfferStatus::Accepted)->assertOk();

        Sanctum::actingAs($buyer);
        $this->patchJson("/api/v1/swap-offers/{$offerId}/status", [
            'status' => SwapOfferStatus::Completed->value,
            'quantity_sold' => 5,
        ])->assertOk();

        $this->assertSame(4, $this->listing->fresh()->quantity);
        $this->assertSame(ListingStatus::Active, $this->listingStatus());
    }

    public function test_marking_a_listing_sold_closes_its_open_deals(): void
    {
        $offerId = $this->offerFrom(User::factory()->create());

        Sanctum::actingAs($this->seller);
        $this->patchJson("/api/v1/listings/{$this->listing->id}", ['status' => 'completed'])->assertOk();

        $this->assertSame(ListingStatus::Completed, $this->listingStatus());
        $this->assertSame(SwapOfferStatus::Declined, SwapOffer::find($offerId)->status);
        $this->assertDatabaseHas('messages', ['swap_offer_id' => $offerId, 'body' => '"Chilli plants" is no longer available.']);
    }

    public function test_deleting_a_listing_closes_its_open_deals(): void
    {
        $offerId = $this->offerFrom(User::factory()->create());

        Sanctum::actingAs($this->seller);
        $this->deleteJson("/api/v1/listings/{$this->listing->id}")->assertOk();

        $this->assertSame(ListingStatus::Deleted, $this->listingStatus());
        $this->assertSame(SwapOfferStatus::Declined, SwapOffer::find($offerId)->status);
    }

    public function test_only_the_seller_can_edit_and_photos_can_be_removed(): void
    {
        $keep = $this->listing->photos()->create(['path' => 'listings/a.jpg', 'sort_order' => 0]);
        $drop = $this->listing->photos()->create(['path' => 'listings/b.jpg', 'sort_order' => 1]);

        Sanctum::actingAs(User::factory()->create());
        $this->patchJson("/api/v1/listings/{$this->listing->id}", ['price' => 1])->assertForbidden();

        Sanctum::actingAs($this->seller);
        $this->patchJson("/api/v1/listings/{$this->listing->id}", [
            'quantity' => 4,
            'remove_photo_ids' => [$drop->id],
        ])->assertOk()->assertJsonPath('data.quantity', 4);

        $this->assertDatabaseHas('listing_photos', ['id' => $keep->id]);
        $this->assertDatabaseMissing('listing_photos', ['id' => $drop->id]);
    }

    public function test_a_sell_listing_can_be_marked_sold_and_put_back_without_resending_its_price(): void
    {
        $this->listing->update(['transaction_type' => 'sell', 'price' => 2.5]);
        Sanctum::actingAs($this->seller);

        $this->patchJson("/api/v1/listings/{$this->listing->id}", ['status' => 'completed'])->assertOk();
        $this->patchJson("/api/v1/listings/{$this->listing->id}", ['status' => 'active', 'quantity' => 2])->assertOk();
        $this->assertSame('2.50', $this->listing->fresh()->price);

        // Blanking the price of a sell listing is still refused...
        $this->patchJson("/api/v1/listings/{$this->listing->id}", ['price' => null])->assertJsonValidationErrors('price');
        // ...and so is switching a swap to "sell" without one.
        $this->listing->update(['transaction_type' => 'swap', 'price' => null]);
        $this->patchJson("/api/v1/listings/{$this->listing->id}", ['transaction_type' => 'sell'])->assertJsonValidationErrors('price');
    }

    public function test_a_new_offer_notifies_the_seller(): void
    {
        $buyer = User::factory()->create(['name' => 'Rina']);
        $offerId = $this->offerFrom($buyer);

        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $this->seller->id,
            'actor_id' => $buyer->id,
            'type' => NotificationType::SwapOfferReceived->value,
            'title' => 'Rina made an offer on "Chilli plants"',
            'body' => 'Can I collect Saturday?',
        ]);
        $this->assertSame($offerId, $this->notificationData($this->seller, NotificationType::SwapOfferReceived)['swap_offer_id']);
    }

    public function test_accepting_reserves_the_listing_and_notifies_the_buyer(): void
    {
        $buyer = User::factory()->create();
        $offerId = $this->offerFrom($buyer);

        $this->setStatus($this->seller, $offerId, SwapOfferStatus::Accepted)->assertOk();

        $this->assertSame(ListingStatus::Reserved, $this->listingStatus());
        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $buyer->id,
            'actor_id' => $this->seller->id,
            'type' => NotificationType::SwapOfferUpdated->value,
        ]);
    }

    public function test_a_reserved_listing_cannot_accept_a_second_offer_or_take_new_ones(): void
    {
        $first = $this->offerFrom(User::factory()->create());
        $second = $this->offerFrom(User::factory()->create());
        $this->setStatus($this->seller, $first, SwapOfferStatus::Accepted)->assertOk();

        $this->setStatus($this->seller, $second, SwapOfferStatus::Accepted)
            ->assertUnprocessable()
            ->assertJsonValidationErrors('status');
        $this->assertSame(SwapOfferStatus::Pending, SwapOffer::find($second)->status);

        Sanctum::actingAs(User::factory()->create());
        $this->postJson("/api/v1/listings/{$this->listing->id}/swap-offers")->assertUnprocessable();
    }

    public function test_cancelling_the_accepted_offer_puts_the_listing_back_on_the_market(): void
    {
        $buyer = User::factory()->create();
        $offerId = $this->offerFrom($buyer);
        $this->setStatus($this->seller, $offerId, SwapOfferStatus::Accepted)->assertOk();

        $this->setStatus($buyer, $offerId, SwapOfferStatus::Canceled)->assertOk();

        $this->assertSame(ListingStatus::Active, $this->listingStatus());
        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $this->seller->id,
            'actor_id' => $buyer->id,
            'type' => NotificationType::SwapOfferUpdated->value,
        ]);
    }

    public function test_declining_a_pending_offer_leaves_the_listing_active(): void
    {
        $offerId = $this->offerFrom(User::factory()->create());

        $this->setStatus($this->seller, $offerId, SwapOfferStatus::Declined)->assertOk();

        $this->assertSame(ListingStatus::Active, $this->listingStatus());
    }

    public function test_completing_marks_the_listing_done_and_closes_the_other_offers(): void
    {
        $buyer = User::factory()->create();
        $other = User::factory()->create();
        $offerId = $this->offerFrom($buyer);
        $otherOfferId = $this->offerFrom($other);
        $this->setStatus($this->seller, $offerId, SwapOfferStatus::Accepted)->assertOk();

        $this->setStatus($this->seller, $offerId, SwapOfferStatus::Completed)->assertOk();

        $this->assertSame(ListingStatus::Completed, $this->listingStatus());
        $this->assertSame(SwapOfferStatus::Declined, SwapOffer::find($otherOfferId)->status);
        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $other->id,
            'type' => NotificationType::SwapOfferUpdated->value,
            'title' => '"Chilli plants" is no longer available',
        ]);
        // The buyer is invited to review.
        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $buyer->id,
            'type' => NotificationType::SwapOfferUpdated->value,
            'body' => 'How did it go? Leave a review for "Chilli plants".',
        ]);
        Sanctum::actingAs($buyer);
        $this->getJson("/api/v1/listings/{$this->listing->id}")->assertJsonPath('data.can_review', true);
    }

    private function notificationData(User $recipient, NotificationType $type): array
    {
        $notification = AppNotification::query()
            ->where('recipient_id', $recipient->id)
            ->where('type', $type)
            ->firstOrFail();

        return (array) $notification->data;
    }
}
