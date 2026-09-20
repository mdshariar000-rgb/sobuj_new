<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('listing_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->timestamps();
        });

        // Seed with the exact display names of the old listing_type enum cases
        // (see App\Enums\ListingType, now removed), so existing listings remap
        // onto a matching row below with zero data loss.
        DB::table('listing_categories')->insert(
            collect([
                'Seeds & Scions',
                'Live Plants & Saplings',
                'Organic Fertilizers',
                'Farm Tools & Equipment',
                'Harvest & Produce',
                'Compost & Soils',
            ])->map(fn ($name) => [
                'name' => $name,
                'created_at' => now(),
                'updated_at' => now(),
            ])->all(),
        );

        // listings.listing_type was a native MySQL ENUM — widen it to a plain
        // string so it can hold any admin-managed category name, then remap
        // the existing rows' short codes onto their matching display name.
        DB::statement('ALTER TABLE listings MODIFY COLUMN listing_type VARCHAR(255) NOT NULL');

        DB::table('listings')->where('listing_type', 'seeds_scions')->update(['listing_type' => 'Seeds & Scions']);
        DB::table('listings')->where('listing_type', 'live_plants')->update(['listing_type' => 'Live Plants & Saplings']);
        DB::table('listings')->where('listing_type', 'organic_fertilizers')->update(['listing_type' => 'Organic Fertilizers']);
        DB::table('listings')->where('listing_type', 'farm_tools')->update(['listing_type' => 'Farm Tools & Equipment']);
        DB::table('listings')->where('listing_type', 'harvest_produce')->update(['listing_type' => 'Harvest & Produce']);
        DB::table('listings')->where('listing_type', 'compost_soils')->update(['listing_type' => 'Compost & Soils']);
    }

    public function down(): void
    {
        DB::table('listings')->where('listing_type', 'Seeds & Scions')->update(['listing_type' => 'seeds_scions']);
        DB::table('listings')->where('listing_type', 'Live Plants & Saplings')->update(['listing_type' => 'live_plants']);
        DB::table('listings')->where('listing_type', 'Organic Fertilizers')->update(['listing_type' => 'organic_fertilizers']);
        DB::table('listings')->where('listing_type', 'Farm Tools & Equipment')->update(['listing_type' => 'farm_tools']);
        DB::table('listings')->where('listing_type', 'Harvest & Produce')->update(['listing_type' => 'harvest_produce']);
        DB::table('listings')->where('listing_type', 'Compost & Soils')->update(['listing_type' => 'compost_soils']);

        DB::statement(
            'ALTER TABLE listings MODIFY COLUMN listing_type ENUM('.
            "'seeds_scions', 'live_plants', 'organic_fertilizers', 'farm_tools', 'harvest_produce', 'compost_soils'".
            ') NOT NULL',
        );

        Schema::dropIfExists('listing_categories');
    }
};
