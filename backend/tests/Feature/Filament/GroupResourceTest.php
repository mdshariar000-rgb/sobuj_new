<?php

namespace Tests\Feature\Filament;

use App\Filament\Resources\GroupResource\Pages\ListGroups;
use App\Models\Group;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class GroupResourceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->actingAs(User::factory()->create(['is_admin' => true]));
    }

    public function test_index_page_lists_groups(): void
    {
        $group = Group::factory()->create(['name' => 'Tomato Growers']);

        Livewire::test(ListGroups::class)
            ->assertSuccessful()
            ->assertCanSeeTableRecords([$group]);
    }

    public function test_verify_and_unverify_actions_toggle_state(): void
    {
        $group = Group::factory()->create();

        Livewire::test(ListGroups::class)
            ->callTableAction('verify', $group)
            ->assertHasNoTableActionErrors();

        $this->assertNotNull($group->refresh()->verified_at);

        Livewire::test(ListGroups::class)
            ->callTableAction('unverify', $group)
            ->assertHasNoTableActionErrors();

        $this->assertNull($group->refresh()->verified_at);
    }

    public function test_deactivate_and_reactivate_toggle_status(): void
    {
        // ->fresh(): a just-created model doesn't reflect the DB's own
        // column default (status) until refetched — real usage always
        // queries fresh from the DB, so this matches that.
        $group = Group::factory()->create()->fresh();

        Livewire::test(ListGroups::class)
            ->callTableAction('deactivate', $group, data: ['reason' => 'Under review'])
            ->assertHasNoTableActionErrors();

        $group->refresh();
        $this->assertSame('deactivated', $group->status->value);
        $this->assertSame('Under review', $group->moderation_reason);

        Livewire::test(ListGroups::class)
            ->callTableAction('reactivate', $group)
            ->assertHasNoTableActionErrors();

        $this->assertSame('active', $group->refresh()->status->value);
    }

    public function test_ban_and_restore_toggle_status(): void
    {
        $group = Group::factory()->create()->fresh();

        Livewire::test(ListGroups::class)
            ->callTableAction('ban', $group, data: ['reason' => 'Repeated policy violations'])
            ->assertHasNoTableActionErrors();

        $group->refresh();
        $this->assertSame('banned', $group->status->value);
        $this->assertSame('Repeated policy violations', $group->moderation_reason);

        Livewire::test(ListGroups::class)
            ->callTableAction('restore', $group)
            ->assertHasNoTableActionErrors();

        $this->assertSame('active', $group->refresh()->status->value);
    }
}
