<?php

namespace Tests\Feature\Filament;

use App\Enums\ListingStatus;
use App\Filament\Resources\ListingResource\Pages\ListListings;
use App\Models\Listing;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class ListingResourceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->actingAs(User::factory()->create(['is_admin' => true]));
    }

    public function test_index_shows_all_listings_by_default_not_just_flagged(): void
    {
        $flagged = Listing::factory()->create(['is_flagged' => true]);
        $notFlagged = Listing::factory()->create(['is_flagged' => false]);

        Livewire::test(ListListings::class)
            ->assertSuccessful()
            ->assertCanSeeTableRecords([$flagged, $notFlagged]);
    }

    public function test_the_flagged_filter_can_still_narrow_to_flagged_only(): void
    {
        $flagged = Listing::factory()->create(['is_flagged' => true]);
        $notFlagged = Listing::factory()->create(['is_flagged' => false]);

        Livewire::test(ListListings::class)
            ->filterTable('is_flagged', true)
            ->assertCanSeeTableRecords([$flagged])
            ->assertCanNotSeeTableRecords([$notFlagged]);
    }

    public function test_approve_action_clears_the_flag(): void
    {
        $listing = Listing::factory()->create([
            'is_flagged' => true,
            'flagged_reason' => 'Reported as spam',
        ]);

        Livewire::test(ListListings::class)
            ->callTableAction('approve', $listing)
            ->assertHasNoTableActionErrors();

        $listing->refresh();
        $this->assertFalse($listing->is_flagged);
        $this->assertNull($listing->flagged_reason);
    }

    public function test_delete_action_logically_deletes_without_removing_the_row(): void
    {
        $listing = Listing::factory()->create(['is_flagged' => true, 'status' => ListingStatus::Active]);

        Livewire::test(ListListings::class)
            ->callTableAction('delete_listing', $listing)
            ->assertHasNoTableActionErrors();

        $listing->refresh();
        $this->assertSame(ListingStatus::Deleted, $listing->status);
        $this->assertDatabaseHas('listings', ['id' => $listing->id]);
    }

    public function test_flag_user_action_suspends_the_listing_owner_with_a_reason(): void
    {
        $owner = User::factory()->create(['is_suspended' => false]);
        $listing = Listing::factory()->create(['user_id' => $owner->id, 'is_flagged' => true]);

        Livewire::test(ListListings::class)
            ->callTableAction('flag_user', $listing, data: ['reason' => 'Repeatedly lists banned species'])
            ->assertHasNoTableActionErrors();

        $owner->refresh();
        $this->assertTrue($owner->is_suspended);
        $this->assertSame('Repeatedly lists banned species', $owner->suspension_reason);
    }

    public function test_admin_can_edit_a_listing_despite_not_owning_it(): void
    {
        // Regression guard: ListingPolicy::update() restricts edits to the listing's
        // own owner for the mobile API. Filament's EditAction delegates to that same
        // policy, so without ListingPolicy::before() granting admins access, this
        // would incorrectly 403 for every listing an admin doesn't personally own.
        $listing = Listing::factory()->create(['is_flagged' => true]);

        Livewire::test(ListListings::class)
            ->callTableAction('edit', $listing, data: ['title' => 'Corrected Title'])
            ->assertHasNoTableActionErrors();

        $this->assertSame('Corrected Title', $listing->refresh()->title);
    }
}
