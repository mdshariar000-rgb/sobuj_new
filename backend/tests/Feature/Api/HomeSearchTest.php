<?php

namespace Tests\Feature\Api;

use App\Enums\ListingStatus;
use App\Models\Group;
use App\Models\Listing;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class HomeSearchTest extends TestCase
{
    use RefreshDatabase;

    public function test_search_finds_items_members_and_groups(): void
    {
        $me = User::factory()->create();
        $seller = User::factory()->create(['name' => 'Tomato Tom', 'location_label' => 'Leeds, England']);
        $listing = Listing::factory()->create(['user_id' => $seller->id, 'title' => 'Cherry tomato seedlings', 'status' => ListingStatus::Active]);
        $group = Group::factory()->create(['name' => 'Tomato Growers']);
        Sanctum::actingAs($me);

        $data = $this->getJson('/api/v1/search?q=tomato')->assertOk()->json('data');

        $this->assertSame([$listing->id], collect($data['listings'])->pluck('id')->all());
        $this->assertSame([$seller->id], collect($data['members'])->pluck('id')->all());
        $this->assertSame([$group->id], collect($data['groups'])->pluck('id')->all());
    }

    public function test_search_by_place_finds_items_from_sellers_there(): void
    {
        $seller = User::factory()->create(['location_label' => 'Headingley, Leeds, England']);
        $listing = Listing::factory()->create(['user_id' => $seller->id, 'title' => 'Basil', 'status' => ListingStatus::Active]);
        Sanctum::actingAs(User::factory()->create());

        $ids = collect($this->getJson('/api/v1/search?q=leeds')->json('data.listings'))->pluck('id');

        $this->assertSame([$listing->id], $ids->all());
    }

    public function test_searches_are_remembered_newest_first_and_can_be_cleared(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/search?q=Basil')->assertOk();
        $this->travel(1)->minutes();
        $this->getJson('/api/v1/search?q=chilli')->assertOk();
        $this->travel(1)->minutes();
        $this->getJson('/api/v1/search?q=basil')->assertOk();

        $this->getJson('/api/v1/search/history')->assertOk()->assertExactJson(['data' => ['basil', 'chilli']]);

        $this->deleteJson('/api/v1/search/history')->assertOk();
        $this->getJson('/api/v1/search/history')->assertExactJson(['data' => []]);
    }

    public function test_picked_for_you_matches_past_searches(): void
    {
        $me = User::factory()->create();
        $match = Listing::factory()->create(['title' => 'Chilli plants', 'status' => ListingStatus::Active]);
        Listing::factory()->create(['title' => 'Garden fork', 'status' => ListingStatus::Active]);
        Sanctum::actingAs($me);

        $this->assertSame([], $this->getJson('/api/v1/feed/marketplace')->json('data.for_you'));

        $this->getJson('/api/v1/search?q=chilli')->assertOk();

        $ids = collect($this->getJson('/api/v1/feed/marketplace')->assertOk()->json('data.for_you'))->pluck('id');
        $this->assertSame([$match->id], $ids->all());
    }

    public function test_a_search_needs_at_least_two_characters(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/search?q=a')->assertUnprocessable()->assertJsonValidationErrors('q');
    }

    public function test_suggest_completes_terms_from_history_items_and_places_without_saving(): void
    {
        $me = User::factory()->create();
        User::factory()->create(['address_city' => 'Tottenham']);
        Listing::factory()->create(['title' => 'Cherry tomato seedlings', 'status' => ListingStatus::Active]);
        Listing::factory()->create(['title' => 'Tomato plants', 'status' => ListingStatus::Active]);
        Listing::factory()->create(['title' => 'Tomato feed', 'status' => ListingStatus::Completed]);
        Sanctum::actingAs($me);
        $this->getJson('/api/v1/search?q=tomato plants')->assertOk();

        $terms = $this->getJson('/api/v1/search/suggest?q=to')->assertOk()->json('data.terms');

        // Past search first, its duplicate item title dropped, prefix
        // matches before the rest, closed items left out, then towns.
        $this->assertSame([
            ['text' => 'tomato plants', 'type' => 'history'],
            ['text' => 'Cherry tomato seedlings', 'type' => 'item'],
            ['text' => 'Tottenham', 'type' => 'place'],
        ], $terms);
        $this->getJson('/api/v1/search/history')->assertExactJson(['data' => ['tomato plants']]);
    }

    public function test_suggest_returns_the_top_few_items_members_and_groups(): void
    {
        $me = User::factory()->create();
        $seller = User::factory()->create(['name' => 'Basil Brush']);
        Listing::factory()->count(4)->create(['user_id' => $seller->id, 'title' => 'Basil', 'status' => ListingStatus::Active]);
        $group = Group::factory()->create(['name' => 'Basil lovers']);
        Sanctum::actingAs($me);

        $data = $this->getJson('/api/v1/search/suggest?q=bas')->assertOk()->json('data');

        $this->assertCount(3, $data['listings']);
        $this->assertSame([$seller->id], collect($data['members'])->pluck('id')->all());
        $this->assertSame([$group->id], collect($data['groups'])->pluck('id')->all());
    }

    public function test_suggest_hides_blocked_users(): void
    {
        $me = User::factory()->create();
        $blocked = User::factory()->create(['name' => 'Rosemary Grower']);
        Listing::factory()->create(['user_id' => $blocked->id, 'title' => 'Rosemary', 'status' => ListingStatus::Active]);
        $me->blockedUsers()->attach($blocked->id);
        Sanctum::actingAs($me);

        $data = $this->getJson('/api/v1/search/suggest?q=rose')->assertOk()->json('data');

        $this->assertSame([], $data['terms']);
        $this->assertSame([], $data['listings']);
        $this->assertSame([], $data['members']);
    }
}
