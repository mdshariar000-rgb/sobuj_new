<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    /**
     * Widens the marketplace's category taxonomy to match the "Category"
     * field on the Create Listing design (Seeds & Scions / Live Plants &
     * Saplings / Organic Fertilizers / Farm Tools & Equipment / Harvest &
     * Produce / Compost & Soils) instead of the narrower physical-form-only
     * set (seed/seedling/cuttings/potted_plant) it shipped with — and
     * relabels condition to the "Specimen Condition" chip set (New/Fresh,
     * Established/Potted, Lightly Used, Organic Certified).
     */
    public function up(): void
    {
        // listing_type is a native MySQL ENUM — widen to the union of old and
        // new values first, since a MODIFY can't rename in place while old
        // rows still hold the old values.
        DB::statement(
            'ALTER TABLE listings MODIFY COLUMN listing_type '.
            "ENUM('seed','seedling','cuttings','potted_plant',".
            "'seeds_scions','live_plants','organic_fertilizers','farm_tools','harvest_produce','compost_soils') NOT NULL"
        );

        DB::table('listings')->where('listing_type', 'seed')->update(['listing_type' => 'seeds_scions']);
        DB::table('listings')->whereIn('listing_type', ['seedling', 'cuttings', 'potted_plant'])
            ->update(['listing_type' => 'live_plants']);

        DB::statement(
            'ALTER TABLE listings MODIFY COLUMN listing_type '.
            "ENUM('seeds_scions','live_plants','organic_fertilizers','farm_tools','harvest_produce','compost_soils') NOT NULL"
        );

        // condition is a plain VARCHAR (see 2026_09_10_000004_...), so this is
        // just a data relabel — no ENUM widen/narrow needed.
        DB::table('listings')->where('condition', 'excellent')->update(['condition' => 'new_fresh']);
        DB::table('listings')->where('condition', 'good')->update(['condition' => 'established_potted']);
        DB::table('listings')->where('condition', 'fair')->update(['condition' => 'lightly_used']);
        DB::table('listings')->where('condition', 'needs_attention')->update(['condition' => 'organic_certified']);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        DB::statement(
            'ALTER TABLE listings MODIFY COLUMN listing_type '.
            "ENUM('seeds_scions','live_plants','organic_fertilizers','farm_tools','harvest_produce','compost_soils',".
            "'seed','seedling','cuttings','potted_plant') NOT NULL"
        );

        DB::table('listings')->where('listing_type', 'seeds_scions')->update(['listing_type' => 'seed']);
        DB::table('listings')->where('listing_type', 'live_plants')->update(['listing_type' => 'seedling']);

        DB::statement(
            'ALTER TABLE listings MODIFY COLUMN listing_type '.
            "ENUM('seed','seedling','cuttings','potted_plant') NOT NULL"
        );

        DB::table('listings')->where('condition', 'new_fresh')->update(['condition' => 'excellent']);
        DB::table('listings')->where('condition', 'established_potted')->update(['condition' => 'good']);
        DB::table('listings')->where('condition', 'lightly_used')->update(['condition' => 'fair']);
        DB::table('listings')->where('condition', 'organic_certified')->update(['condition' => 'needs_attention']);
    }
};
