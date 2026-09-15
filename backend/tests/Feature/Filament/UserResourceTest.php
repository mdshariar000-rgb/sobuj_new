<?php

namespace Tests\Feature\Filament;

use App\Enums\SwapOfferStatus;
use App\Filament\Resources\UserResource;
use App\Filament\Resources\UserResource\Pages\ListUsers;
use App\Models\Listing;
use App\Models\SwapOffer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class UserResourceTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::factory()->create(['is_admin' => true]);
        $this->actingAs($this->admin);
    }

    public function test_non_admin_cannot_access_the_panel(): void
    {
        $user = User::factory()->create(['is_admin' => false]);

        $this->actingAs($user)
            ->get(UserResource::getUrl('index'))
            ->assertForbidden();
    }

    public function test_index_page_renders_and_lists_users(): void
    {
        $others = User::factory()->count(3)->create();

        Livewire::test(ListUsers::class)
            ->assertSuccessful()
            ->assertCanSeeTableRecords($others);
    }

    public function test_ban_temporarily_sets_a_real_expiry_and_unban_clears_it(): void
    {
        $user = User::factory()->create(['is_suspended' => false]);

        Livewire::test(ListUsers::class)
            ->callTableAction('ban_temporarily', $user, data: [
                'days' => 7,
                'suspension_reason' => 'Repeated spam listings',
            ])
            ->assertHasNoTableActionErrors();

        $user->refresh();
        $this->assertTrue($user->is_suspended);
        $this->assertSame('Repeated spam listings', $user->suspension_reason);
        $this->assertNotNull($user->suspended_until);
        $this->assertTrue($user->suspended_until->isFuture());
        $this->assertTrue($user->isCurrentlySuspended());

        Livewire::test(ListUsers::class)
            ->callTableAction('unsuspend', $user)
            ->assertHasNoTableActionErrors();

        $user->refresh();
        $this->assertFalse($user->is_suspended);
        $this->assertNull($user->suspension_reason);
        $this->assertNull($user->suspended_until);
        $this->assertFalse($user->isCurrentlySuspended());
    }

    public function test_ban_permanently_leaves_suspended_until_blank_and_never_expires(): void
    {
        $user = User::factory()->create(['is_suspended' => false]);

        Livewire::test(ListUsers::class)
            ->callTableAction('ban_permanently', $user, data: ['suspension_reason' => 'Fraudulent listings'])
            ->assertHasNoTableActionErrors();

        $user->refresh();
        $this->assertTrue($user->is_suspended);
        $this->assertSame('Fraudulent listings', $user->suspension_reason);
        $this->assertNull($user->suspended_until);

        // No auto-expiry, even after real time passes.
        $this->travel(30)->days();
        $this->assertTrue($user->isCurrentlySuspended());
    }

    public function test_a_temporary_ban_actually_expires(): void
    {
        $user = User::factory()->create([
            'is_suspended' => true,
            'suspended_until' => now()->addDay(),
            'suspension_reason' => 'Cooling off period',
        ]);

        $this->assertTrue($user->isCurrentlySuspended());

        $this->travel(2)->days();

        $this->assertFalse($user->refresh()->isCurrentlySuspended());
    }

    public function test_verify_and_unverify_actions_toggle_state(): void
    {
        $user = User::factory()->create(['verified_at' => null]);

        Livewire::test(ListUsers::class)
            ->callTableAction('verify', $user)
            ->assertHasNoTableActionErrors();

        $this->assertNotNull($user->refresh()->verified_at);

        Livewire::test(ListUsers::class)
            ->callTableAction('unverify', $user)
            ->assertHasNoTableActionErrors();

        $this->assertNull($user->refresh()->verified_at);
    }

    public function test_completed_swaps_count_column_reflects_swaps_on_both_sides(): void
    {
        $user = User::factory()->create();

        // As the requester on one completed swap...
        SwapOffer::factory()->create([
            'requester_id' => $user->id,
            'status' => SwapOfferStatus::Completed,
        ]);

        // ...and as the listing owner on another.
        $ownedListing = Listing::factory()->create(['user_id' => $user->id]);
        SwapOffer::factory()->create([
            'listing_id' => $ownedListing->id,
            'status' => SwapOfferStatus::Completed,
        ]);

        // A pending (not completed) offer that should NOT be counted.
        SwapOffer::factory()->create([
            'requester_id' => $user->id,
            'status' => SwapOfferStatus::Pending,
        ]);

        $counted = User::query()->withCompletedSwapsCount()->whereKey($user->id)->first();

        $this->assertSame(2, (int) $counted->completed_swaps_count);
    }
}
