<?php

namespace Tests\Feature\Filament;

use App\Filament\Resources\BannedSpeciesResource\Pages\CreateBannedSpecies;
use App\Filament\Resources\BannedSpeciesResource\Pages\EditBannedSpecies;
use App\Filament\Resources\BannedSpeciesResource\Pages\ListBannedSpecies;
use App\Models\BannedSpecies;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class BannedSpeciesResourceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->actingAs(User::factory()->create(['is_admin' => true]));
    }

    public function test_index_page_lists_banned_species(): void
    {
        $species = BannedSpecies::factory()->create();

        Livewire::test(ListBannedSpecies::class)
            ->assertSuccessful()
            ->assertCanSeeTableRecords([$species]);
    }

    public function test_can_create_a_banned_species(): void
    {
        Livewire::test(CreateBannedSpecies::class)
            ->fillForm([
                'name' => 'Japanese Knotweed',
                'notes' => 'Highly invasive; prohibited in most jurisdictions.',
            ])
            ->call('create')
            ->assertHasNoFormErrors();

        $this->assertDatabaseHas('banned_species', ['name' => 'Japanese Knotweed']);
    }

    public function test_name_must_be_unique(): void
    {
        BannedSpecies::factory()->create(['name' => 'Kudzu']);

        Livewire::test(CreateBannedSpecies::class)
            ->fillForm(['name' => 'Kudzu'])
            ->call('create')
            ->assertHasFormErrors(['name' => 'unique']);
    }

    public function test_can_edit_a_banned_species(): void
    {
        $species = BannedSpecies::factory()->create(['name' => 'Giant Hogweed']);

        Livewire::test(EditBannedSpecies::class, ['record' => $species->getRouteKey()])
            ->fillForm(['name' => 'Giant Hogweed (updated)'])
            ->call('save')
            ->assertHasNoFormErrors();

        $this->assertSame('Giant Hogweed (updated)', $species->refresh()->name);
    }
}
