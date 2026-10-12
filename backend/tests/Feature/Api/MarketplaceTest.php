<?php

namespace Tests\Feature\Api;

use App\Enums\ListingStatus;
use App\Enums\MessageType;
use App\Enums\SwapOfferStatus;
use App\Enums\TransactionType;
use App\Models\Listing;
use App\Models\SwapOffer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class MarketplaceTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_wanted_listing_can_be_created_without_photos_or_price(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->postJson('/api/v1/listings', [
            'title' => 'Wanted: Heavy Duty Broadfork',
            'listing_type' => 'Live plants',
            'transaction_type' => 'wanted',
            'looking_for' => 'A sturdy broadfork or U-bar digger, used is fine.',
            'latitude' => 23.780636,
            'longitude' => 90.279785,
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.transaction_type', 'wanted');
        $response->assertJsonPath('data.price', null);
    }

    public function test_a_wanted_listing_can_carry_an_optional_budget_price(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->postJson('/api/v1/listings', [
            'title' => 'Wanted: Heavy Duty Broadfork',
            'listing_type' => 'Live plants',
            'transaction_type' => 'wanted',
            'price' => 85,
            'latitude' => 23.780636,
            'longitude' => 90.279785,
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.price', 85.0);
    }

    public function test_the_nearby_search_can_filter_to_wanted_listings(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $wanted = Listing::factory()->create([
            'transaction_type' => TransactionType::Wanted,
            'status' => ListingStatus::Active,
        ]);
        $wanted->setLocation(23.780636, 90.279785)->save();

        $forSale = Listing::factory()->create([
            'transaction_type' => TransactionType::Sell,
            'price' => 10,
            'status' => ListingStatus::Active,
        ]);
        $forSale->setLocation(23.781, 90.280)->save();

        $response = $this->getJson('/api/v1/listings/nearby?'.http_build_query([
            'latitude' => 23.780636,
            'longitude' => 90.279785,
            'radius_km' => 50,
            'transaction_type' => 'wanted',
        ]));

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id')->all();
        $this->assertSame([$wanted->id], $ids);
    }

    public function test_a_user_can_save_and_unsave_a_listing(): void
    {
        $listing = Listing::factory()->create();
        $saver = User::factory()->create();
        Sanctum::actingAs($saver);

        $this->postJson("/api/v1/listings/{$listing->id}/save")
            ->assertOk()
            ->assertJsonPath('data.is_saved', true);

        $this->assertDatabaseHas('saved_listings', ['listing_id' => $listing->id, 'user_id' => $saver->id]);

        $this->deleteJson("/api/v1/listings/{$listing->id}/save")
            ->assertOk()
            ->assertJsonPath('data.is_saved', false);

        $this->assertDatabaseMissing('saved_listings', ['listing_id' => $listing->id, 'user_id' => $saver->id]);
    }

    public function test_the_nearby_search_reports_is_saved_per_listing(): void
    {
        $listing = Listing::factory()->create(['status' => ListingStatus::Active]);
        $listing->setLocation(23.780636, 90.279785)->save();
        $saver = User::factory()->create();
        $listing->savedBy()->attach($saver->id);

        Sanctum::actingAs($saver);
        $response = $this->getJson('/api/v1/listings/nearby?'.http_build_query([
            'latitude' => 23.780636,
            'longitude' => 90.279785,
            'radius_km' => 50,
        ]));
        $response->assertJsonPath('data.0.is_saved', true);

        Sanctum::actingAs(User::factory()->create());
        $response = $this->getJson('/api/v1/listings/nearby?'.http_build_query([
            'latitude' => 23.780636,
            'longitude' => 90.279785,
            'radius_km' => 50,
        ]));
        $response->assertJsonPath('data.0.is_saved', false);
    }

    public function test_sort_newest_orders_by_creation_time_instead_of_distance(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $older = Listing::factory()->create(['status' => ListingStatus::Active, 'created_at' => now()->subDays(2)]);
        $older->setLocation(23.780636, 90.279785)->save(); // exact origin — nearest

        $newer = Listing::factory()->create(['status' => ListingStatus::Active, 'created_at' => now()]);
        $newer->setLocation(23.79, 90.29)->save(); // further away

        // Default (nearest-first): the closer, older listing comes first.
        $nearest = $this->getJson('/api/v1/listings/nearby?'.http_build_query([
            'latitude' => 23.780636,
            'longitude' => 90.279785,
            'radius_km' => 50,
        ]));
        $this->assertSame($older->id, $nearest->json('data.0.id'));

        // sort=newest: the more recently created listing comes first, regardless of distance.
        $newest = $this->getJson('/api/v1/listings/nearby?'.http_build_query([
            'latitude' => 23.780636,
            'longitude' => 90.279785,
            'radius_km' => 50,
            'sort' => 'newest',
        ]));
        $this->assertSame($newer->id, $newest->json('data.0.id'));
    }

    public function test_a_listing_can_be_created_with_description_condition_and_handover_note(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->postJson('/api/v1/listings', [
            'title' => 'Meyer Lemon Rootstock',
            'listing_type' => 'Live plants',
            'transaction_type' => 'swap',
            'description' => 'Healthy rootstock, grown from seed two years ago.',
            'condition' => 'new_fresh',
            'looking_for' => 'Fig cuttings',
            'handover_note' => 'Pickup only, weekday evenings.',
            'latitude' => 23.780636,
            'longitude' => 90.279785,
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.description', 'Healthy rootstock, grown from seed two years ago.');
        $response->assertJsonPath('data.condition', 'new_fresh');
        $response->assertJsonPath('data.condition_label', 'New / Fresh');
        $response->assertJsonPath('data.handover_note', 'Pickup only, weekday evenings.');
    }

    public function test_a_sell_listing_can_be_created_with_quantity_and_contact(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->postJson('/api/v1/listings', [
            'title' => 'Beefsteak Tomato Seeds',
            'description' => 'Heirloom seeds, good germination.',
            'listing_type' => 'Live plants',
            'transaction_type' => 'sell',
            'price' => 1.55,
            'quantity' => 10,
            'contact' => '07700 900123',
            'latitude' => 23.780636,
            'longitude' => 90.279785,
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.quantity', 10);
        $response->assertJsonPath('data.contact', '07700 900123');
        $this->assertDatabaseHas('listings', ['title' => 'Beefsteak Tomato Seeds', 'quantity' => 10]);
    }

    public function test_a_listings_contact_is_only_shown_to_its_seller(): void
    {
        $seller = User::factory()->create();
        Sanctum::actingAs($seller);

        $listingId = $this->postJson('/api/v1/listings', [
            'title' => 'Beefsteak Tomato Seeds',
            'listing_type' => 'Live plants',
            'transaction_type' => 'sell',
            'price' => 1.55,
            'quantity' => 10,
            'contact' => 'seller@example.com',
            'latitude' => 23.780636,
            'longitude' => 90.279785,
        ])->json('data.id');

        $this->getJson("/api/v1/listings/{$listingId}")
            ->assertJsonPath('data.contact', 'seller@example.com');

        Sanctum::actingAs(User::factory()->create());

        $this->getJson("/api/v1/listings/{$listingId}")
            ->assertOk()
            ->assertJsonPath('data.quantity', 10)
            ->assertJsonMissingPath('data.contact');
    }

    public function test_a_listing_without_quantity_or_contact_still_works_for_older_apps(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->postJson('/api/v1/listings', [
            'title' => 'Rare Orchid',
            'listing_type' => 'Live plants',
            'transaction_type' => 'sell',
            'price' => 25,
            'latitude' => 23.780636,
            'longitude' => 90.279785,
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.quantity', null);
    }

    public function test_quantity_must_be_a_positive_whole_number(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/listings', [
            'title' => 'Rare Orchid',
            'listing_type' => 'Live plants',
            'transaction_type' => 'sell',
            'price' => 25,
            'quantity' => 0,
        ])->assertJsonValidationErrors('quantity');
    }

    public function test_a_users_public_profile_exposes_only_safe_fields_and_their_active_listings(): void
    {
        $seller = User::factory()->create(['name' => 'Ayesha Rahman']);
        $active = Listing::factory()->create(['user_id' => $seller->id, 'status' => ListingStatus::Active]);
        Listing::factory()->create(['user_id' => $seller->id, 'status' => ListingStatus::Deleted]);

        Sanctum::actingAs(User::factory()->create());

        $profile = $this->getJson("/api/v1/users/{$seller->id}");
        $profile->assertOk();
        $profile->assertJsonPath('data.name', 'Ayesha Rahman');
        $profile->assertJsonMissingPath('data.email');
        $profile->assertJsonMissingPath('data.is_suspended');

        $listings = $this->getJson("/api/v1/users/{$seller->id}/listings");
        $listings->assertOk();
        $ids = collect($listings->json('data'))->pluck('id')->all();
        $this->assertSame([$active->id], $ids);
    }

    public function test_proposing_a_trade_twice_on_the_same_listing_reuses_the_open_offer(): void
    {
        $listing = Listing::factory()->create(['status' => ListingStatus::Active]);
        $buyer = User::factory()->create();
        Sanctum::actingAs($buyer);

        $first = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers", [
            'offer_details' => ['note' => 'Interested!'],
        ]);
        $first->assertCreated();
        $firstId = $first->json('data.id');

        // Tapping "Propose Trade" again (e.g. a second visit to the listing) should
        // reopen the same thread, not spawn a duplicate offer.
        $second = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers", [
            'offer_details' => ['note' => 'Still interested!'],
        ]);
        $second->assertOk();
        $this->assertSame($firstId, $second->json('data.id'));
        $this->assertSame(1, SwapOffer::where('listing_id', $listing->id)->count());
    }

    public function test_proposing_a_trade_again_after_the_first_offer_was_declined_creates_a_new_one(): void
    {
        $listing = Listing::factory()->create(['status' => ListingStatus::Active]);
        $buyer = User::factory()->create();

        $declined = SwapOffer::factory()->create([
            'listing_id' => $listing->id,
            'requester_id' => $buyer->id,
            'status' => SwapOfferStatus::Declined,
        ]);

        Sanctum::actingAs($buyer);
        $response = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers");

        $response->assertCreated();
        $this->assertNotSame($declined->id, $response->json('data.id'));
    }

    public function test_a_swap_offer_response_includes_the_listing_owner(): void
    {
        $seller = User::factory()->create(['name' => 'Owner Grower']);
        $listing = Listing::factory()->create(['user_id' => $seller->id, 'status' => ListingStatus::Active]);
        Sanctum::actingAs(User::factory()->create());

        $response = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers");

        $response->assertCreated();
        $response->assertJsonPath('data.listing.owner.name', 'Owner Grower');
    }

    public function test_a_message_can_be_sent_with_only_an_image_and_no_body(): void
    {
        Storage::fake('public');

        $listing = Listing::factory()->create(['status' => ListingStatus::Active]);
        $buyer = User::factory()->create();
        Sanctum::actingAs($buyer);

        $offer = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers")->json('data');

        $response = $this->post("/api/v1/swap-offers/{$offer['id']}/messages", [
            'image' => UploadedFile::fake()->image('plant.jpg'),
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.body', null);
        $this->assertNotNull($response->json('data.image_url'));
    }

    public function test_a_message_requires_either_a_body_or_an_image(): void
    {
        $listing = Listing::factory()->create(['status' => ListingStatus::Active]);
        $buyer = User::factory()->create();
        Sanctum::actingAs($buyer);

        $offer = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers")->json('data');

        $response = $this->postJson("/api/v1/swap-offers/{$offer['id']}/messages", []);

        $response->assertUnprocessable();
        $response->assertJsonValidationErrors(['body']);
    }

    public function test_the_offers_index_includes_each_threads_latest_message(): void
    {
        $listing = Listing::factory()->create(['status' => ListingStatus::Active]);
        $buyer = User::factory()->create();
        Sanctum::actingAs($buyer);

        $offer = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers")->json('data');
        $this->postJson("/api/v1/swap-offers/{$offer['id']}/messages", [
            'body' => 'Is this still available?',
        ]);

        $response = $this->getJson('/api/v1/swap-offers');

        $response->assertOk();
        $response->assertJsonPath('data.0.last_message.body', 'Is this still available?');
        $response->assertJsonPath('data.0.last_message.sender_id', $buyer->id);
        $response->assertJsonPath('data.0.last_message.is_system_event', false);
    }

    public function test_unread_count_reflects_unread_messages_and_clears_on_open(): void
    {
        $listing = Listing::factory()->create(['status' => ListingStatus::Active]);
        $buyer = User::factory()->create();
        Sanctum::actingAs($buyer);

        $offer = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers")->json('data');
        $offerId = $offer['id'];

        Sanctum::actingAs($listing->user);
        $this->postJson("/api/v1/swap-offers/{$offerId}/messages", [
            'body' => 'Yes, still available!',
        ])->assertCreated();

        Sanctum::actingAs($buyer);
        $indexBefore = $this->getJson('/api/v1/swap-offers');
        $indexBefore->assertOk();
        // The buyer's own "made an offer" system message plus the seller's
        // reply are both unread from the buyer's side.
        $this->assertSame(2, $indexBefore->json('data.0.unread_count'));

        // Opening the thread (GET messages) marks everything not sent by the
        // buyer as read — see MessageController::index().
        $this->getJson("/api/v1/swap-offers/{$offerId}/messages")->assertOk();

        $indexAfter = $this->getJson('/api/v1/swap-offers');
        $indexAfter->assertOk();
        $this->assertSame(0, $indexAfter->json('data.0.unread_count'));
    }

    public function test_opening_a_long_thread_shows_the_most_recent_messages_not_the_oldest(): void
    {
        $listing = Listing::factory()->create(['status' => ListingStatus::Active]);
        $buyer = User::factory()->create();
        Sanctum::actingAs($buyer);

        $offer = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers")->json('data');
        $swapOffer = SwapOffer::find($offer['id']);

        // More than MessageController::PER_PAGE (50) so the thread spans
        // more than one page. created_at is set after create() since it
        // isn't mass-assignable on Message — passing it to create() would
        // silently be dropped, leaving every row tied to the same instant.
        for ($i = 1; $i <= 55; $i++) {
            $message = $swapOffer->messages()->create([
                'sender_id' => $buyer->id,
                'message_type' => MessageType::Text,
                'body' => "Message {$i}",
            ]);
            $message->created_at = now()->addSeconds($i);
            $message->save();
        }

        $response = $this->getJson("/api/v1/swap-offers/{$swapOffer->id}/messages");
        $response->assertOk();
        $bodies = collect($response->json('data'))->pluck('body');

        // Opening the thread should land on the tail of the conversation —
        // like any real chat app — not page 1 of its oldest messages.
        $this->assertCount(50, $bodies);
        $this->assertSame('Message 55', $bodies->last());
        $this->assertNotContains('Message 1', $bodies->all());
    }

    public function test_saved_listings_returns_only_what_the_user_saved_most_recent_first(): void
    {
        $saver = User::factory()->create();
        Sanctum::actingAs($saver);

        $first = Listing::factory()->create(['status' => ListingStatus::Active]);
        $second = Listing::factory()->create(['status' => ListingStatus::Active]);
        $neverSaved = Listing::factory()->create(['status' => ListingStatus::Active]);

        $this->postJson("/api/v1/listings/{$first->id}/save")->assertOk();
        $this->postJson("/api/v1/listings/{$second->id}/save")->assertOk();

        $response = $this->getJson('/api/v1/listings/saved');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id')->all();
        $this->assertSame([$second->id, $first->id], $ids);
        $this->assertNotContains($neverSaved->id, $ids);
        $response->assertJsonPath('data.0.is_saved', true);
    }

    public function test_saved_listings_excludes_a_listing_the_owner_deleted(): void
    {
        $saver = User::factory()->create();
        $listing = Listing::factory()->create(['status' => ListingStatus::Active]);
        $listing->savedBy()->attach($saver->id);
        $listing->update(['status' => ListingStatus::Deleted]);

        Sanctum::actingAs($saver);
        $response = $this->getJson('/api/v1/listings/saved');

        $response->assertOk();
        $this->assertSame([], $response->json('data'));
    }
}
