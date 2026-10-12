<?php

namespace Tests\Feature\Api;

use App\Models\Listing;
use App\Models\ListingCategory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class ListingCategoryRenameTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_marketplace_uses_the_short_category_names(): void
    {
        $names = ListingCategory::pluck('name')->all();

        $this->assertContains('Seed', $names);
        $this->assertContains('Live plants', $names);
        $this->assertNotContains('Seeds & Scions', $names);
        $this->assertNotContains('Live Plants & Saplings', $names);
    }

    public function test_renaming_a_category_moves_its_listings_with_it(): void
    {
        $listing = Listing::factory()->create(['listing_type' => 'Seed']);
        $other = Listing::factory()->create(['listing_type' => 'Live plants']);

        ListingCategory::where('name', 'Seed')->first()->update(['name' => 'Seeds']);

        $this->assertSame('Seeds', $listing->fresh()->listing_type);
        $this->assertSame('Live plants', $other->fresh()->listing_type);
    }
}
