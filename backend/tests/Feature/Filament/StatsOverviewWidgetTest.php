<?php

namespace Tests\Feature\Filament;

use App\Enums\ListingStatus;
use App\Enums\SwapOfferStatus;
use App\Filament\Widgets\StatsOverviewWidget;
use App\Models\Listing;
use App\Models\SwapOffer;
use App\Models\User;
use Filament\Widgets\StatsOverviewWidget\Stat;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class StatsOverviewWidgetTest extends TestCase
{
    use RefreshDatabase;

    public function test_widget_reports_correct_counts(): void
    {
        // Every factory call below pins its foreign keys to one of these two users
        // explicitly, rather than letting SwapOffer/Listing factories cascade-create
        // their own related User/Listing rows (they would otherwise, since
        // SwapOfferFactory and ListingFactory both default those to `Model::factory()`)
        // — needed to keep the active-user count in this test deterministic.
        $admin = User::factory()->create(['is_admin' => true, 'is_suspended' => false]);
        $owner = User::factory()->create(['is_suspended' => false]);

        $this->actingAs($admin);

        User::factory()->count(2)->create(['is_suspended' => false]);
        User::factory()->count(3)->create(['is_suspended' => true]);

        $listingA = Listing::factory()->create(['user_id' => $owner->id, 'status' => ListingStatus::Active]);
        $listingB = Listing::factory()->create(['user_id' => $owner->id, 'status' => ListingStatus::Active]);
        Listing::factory()->count(2)->create(['user_id' => $owner->id, 'status' => ListingStatus::Active]);
        Listing::factory()->create(['user_id' => $owner->id, 'status' => ListingStatus::Deleted]);

        SwapOffer::factory()->create(['listing_id' => $listingA->id, 'requester_id' => $owner->id, 'status' => SwapOfferStatus::Completed]);
        SwapOffer::factory()->create(['listing_id' => $listingB->id, 'requester_id' => $owner->id, 'status' => SwapOfferStatus::Completed]);
        SwapOffer::factory()->create(['listing_id' => $listingA->id, 'requester_id' => $owner->id, 'status' => SwapOfferStatus::Pending]);

        $component = Livewire::test(StatsOverviewWidget::class);
        $component->assertSuccessful();

        /** @var array<int, Stat> $stats */
        $stats = (fn () => $this->getStats())->call($component->instance());

        // admin + owner + 2 explicitly active = 4 (the 3 explicitly suspended excluded).
        $this->assertSame('4', (string) $stats[0]->getValue());
        $this->assertSame('2', (string) $stats[1]->getValue());
        $this->assertSame('4', (string) $stats[2]->getValue());
    }
}
