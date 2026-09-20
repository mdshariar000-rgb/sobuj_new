<?php

namespace Tests\Feature\Api;

use App\Models\BannedSpecies;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ListingBannedSpeciesTest extends TestCase
{
    use RefreshDatabase;

    public function test_creating_a_listing_with_a_banned_species_title_is_rejected(): void
    {
        BannedSpecies::factory()->create(['name' => 'Japanese Knotweed']);

        Sanctum::actingAs(User::factory()->create());

        $response = $this->postJson('/api/v1/listings', [
            'title' => 'Japanese Knotweed cuttings, well established',
            'listing_type' => 'Live Plants & Saplings',
            'transaction_type' => 'swap',
        ]);

        $response->assertUnprocessable();
        $response->assertJsonValidationErrors(['title']);
        $this->assertDatabaseCount('listings', 0);
    }

    public function test_creating_a_listing_with_a_clean_title_succeeds(): void
    {
        BannedSpecies::factory()->create(['name' => 'Japanese Knotweed']);

        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/listings', [
            'title' => 'Cherry tomato seeds',
            'listing_type' => 'Seeds & Scions',
            'transaction_type' => 'swap',
        ]);

        $response->assertCreated();
        $this->assertDatabaseHas('listings', ['title' => 'Cherry tomato seeds', 'user_id' => $user->id]);
    }
}
