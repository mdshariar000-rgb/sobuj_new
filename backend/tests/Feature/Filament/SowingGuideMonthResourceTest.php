<?php

namespace Tests\Feature\Filament;

use App\Filament\Resources\SowingGuideMonthResource;
use App\Filament\Resources\SowingGuideMonthResource\Pages\EditSowingGuideMonth;
use App\Filament\Resources\SowingGuideMonthResource\Pages\ListSowingGuideMonths;
use App\Models\SowingGuideMonth;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class SowingGuideMonthResourceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->actingAs(User::factory()->create(['is_admin' => true]));
    }

    public function test_index_lists_all_twelve_months(): void
    {
        Livewire::test(ListSowingGuideMonths::class)
            ->assertSuccessful()
            ->assertCanSeeTableRecords(SowingGuideMonth::all())
            ->assertCountTableRecords(12);
    }

    public function test_can_edit_a_months_plants(): void
    {
        $october = SowingGuideMonth::query()->where('month', 10)->firstOrFail();

        Livewire::test(EditSowingGuideMonth::class, ['record' => $october->getRouteKey()])
            ->assertSuccessful()
            ->fillForm([
                'outdoors' => ['Garlic', 'Winter onions'],
                'under_cover' => ['Microgreens'],
            ])
            ->call('save')
            ->assertHasNoFormErrors();

        $october->refresh();
        $this->assertSame(['Garlic', 'Winter onions'], $october->outdoors);
        $this->assertSame(['Microgreens'], $october->under_cover);
    }

    public function test_months_cannot_be_created_or_deleted(): void
    {
        $this->assertFalse(SowingGuideMonthResource::canCreate());
        $this->assertFalse(SowingGuideMonthResource::canDelete(SowingGuideMonth::firstOrFail()));
    }

    public function test_non_admins_cannot_open_it(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => false]));

        $this->get(SowingGuideMonthResource::getUrl('index'))->assertForbidden();
    }
}
