<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('group_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->timestamps();
        });

        // A starter set an admin can edit/add to/remove from at any time via
        // the admin panel — chosen to match the substrings GroupCard's own
        // icon-matching already looks for (hydro/soil/compost/orchid/flor/
        // home/permacul/fruit/orchard), so a real category picked from this
        // list gets a real matched icon, not the generic fallback.
        DB::table('group_categories')->insert(
            collect([
                'Vegetable Growing',
                'Fruit & Orchard',
                'Herbs & Spices',
                'Hydroponics & Tech',
                'Soil & Composting',
                'Orchids & Flowers',
                'Home & Permaculture',
                'Seed Saving & Propagation',
                'Pest & Disease Management',
                'Tools & Equipment',
                'Community & Events',
            ])->map(fn ($name) => [
                'name' => $name,
                'created_at' => now(),
                'updated_at' => now(),
            ])->all(),
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('group_categories');
    }
};
