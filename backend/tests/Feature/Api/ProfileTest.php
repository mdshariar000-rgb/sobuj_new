<?php

namespace Tests\Feature\Api;

use App\Enums\ListingStatus;
use App\Models\Listing;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ProfileTest extends TestCase
{
    use RefreshDatabase;

    public function test_me_includes_real_posts_and_active_listings_counts(): void
    {
        $user = User::factory()->create();
        Post::factory()->count(2)->create(['author_id' => $user->id]);
        Listing::factory()->create(['user_id' => $user->id, 'status' => ListingStatus::Active]);
        Listing::factory()->create(['user_id' => $user->id, 'status' => ListingStatus::Completed]);

        Sanctum::actingAs($user);
        $response = $this->getJson('/api/v1/auth/me');

        $response->assertOk();
        $response->assertJsonPath('data.posts_count', 2);
        $response->assertJsonPath('data.active_listings_count', 1);
    }

    public function test_updating_the_profile_persists_every_field(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->patchJson('/api/v1/auth/me', [
            'name' => 'Maya Lin',
            'username' => 'mayagrows',
            'bio' => 'Certified permaculture enthusiast.',
            'phone' => '+17075550198',
            'location_label' => 'Napa Valley, CA',
            'growing_interests' => ['Urban Orchard', 'Heritage Seeds'],
            'show_handover_radius' => false,
        ]);

        $response->assertOk();
        $response->assertJsonPath('data.name', 'Maya Lin');
        $response->assertJsonPath('data.username', 'mayagrows');
        $response->assertJsonPath('data.bio', 'Certified permaculture enthusiast.');
        $response->assertJsonPath('data.phone', '+17075550198');
        $response->assertJsonPath('data.location_label', 'Napa Valley, CA');
        $response->assertJsonPath('data.growing_interests', ['Urban Orchard', 'Heritage Seeds']);
        $response->assertJsonPath('data.show_handover_radius', false);

        $this->assertDatabaseHas('users', ['id' => $user->id, 'username' => 'mayagrows']);
    }

    public function test_updating_the_profile_as_real_multipart_form_data_accepts_the_boolean(): void
    {
        // The mobile app can't use a plain JSON PATCH here — it needs
        // multipart to also support avatar/cover uploads — so it sends a
        // POST with `_method=PATCH` and every field as a literal string,
        // exactly like a browser form submission. Unlike patchJson()'s real
        // PHP boolean, multipart has no boolean type: Dio stringifies
        // show_handover_radius to the literal word "false"/"true", which
        // used to 422 against Laravel's `boolean` rule (it only accepts
        // 1/0/"1"/"0") — silently failing every real profile save. See
        // UpdateProfileRequest::prepareForValidation().
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->call('POST', '/api/v1/auth/me', [
            '_method' => 'PATCH',
            'name' => 'Maya Lin',
            'show_handover_radius' => 'false',
        ]);

        $response->assertOk();
        $response->assertJsonPath('data.show_handover_radius', false);

        $response = $this->call('POST', '/api/v1/auth/me', [
            '_method' => 'PATCH',
            'name' => 'Maya Lin',
            'show_handover_radius' => 'true',
        ]);

        $response->assertOk();
        $response->assertJsonPath('data.show_handover_radius', true);
    }

    public function test_username_must_be_unique(): void
    {
        User::factory()->create(['username' => 'mayagrows']);
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->patchJson('/api/v1/auth/me', ['username' => 'mayagrows']);

        $response->assertUnprocessable();
        $response->assertJsonValidationErrors(['username']);
    }

    public function test_uploading_an_avatar_and_cover_photo_stores_them(): void
    {
        Storage::fake('public');

        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->patch('/api/v1/auth/me', [
            'avatar' => UploadedFile::fake()->image('avatar.jpg'),
            'cover_photo' => UploadedFile::fake()->image('cover.jpg'),
        ]);

        $response->assertOk();
        $this->assertNotNull($response->json('data.avatar_url'));
        $this->assertNotNull($response->json('data.cover_photo_url'));
    }

    public function test_turning_off_handover_radius_hides_location_from_other_viewers_but_not_the_owner(): void
    {
        $owner = User::factory()->create(['show_handover_radius' => false]);
        $listing = Listing::factory()->create(['user_id' => $owner->id, 'status' => ListingStatus::Active]);

        Sanctum::actingAs($owner);
        $this->getJson("/api/v1/listings/{$listing->id}")
            ->assertJsonPath('data.location', fn ($location) => $location !== null);

        $viewer = User::factory()->create();
        Sanctum::actingAs($viewer);
        $this->getJson("/api/v1/listings/{$listing->id}")
            ->assertJsonPath('data.location', null);
    }

    public function test_viewing_a_listing_increments_its_view_count_only_for_non_owners(): void
    {
        $owner = User::factory()->create();
        $listing = Listing::factory()->create(['user_id' => $owner->id, 'status' => ListingStatus::Active]);

        Sanctum::actingAs($owner);
        $this->getJson("/api/v1/listings/{$listing->id}")->assertJsonPath('data.views_count', 0);

        $viewer = User::factory()->create();
        Sanctum::actingAs($viewer);
        $this->getJson("/api/v1/listings/{$listing->id}")->assertJsonPath('data.views_count', 1);
    }

    public function test_home_feed_can_be_filtered_to_one_authors_posts(): void
    {
        $author = User::factory()->create();
        $other = User::factory()->create();
        Post::factory()->create(['author_id' => $author->id]);
        Post::factory()->create(['author_id' => $other->id]);

        Sanctum::actingAs($author);
        $response = $this->getJson("/api/v1/feed?author_id={$author->id}");

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id')->all();
        $this->assertCount(1, $ids);
    }
}
