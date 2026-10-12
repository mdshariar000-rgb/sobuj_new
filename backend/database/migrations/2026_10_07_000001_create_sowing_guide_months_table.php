<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('sowing_guide_months', function (Blueprint $table) {
            $table->id();
            $table->unsignedTinyInteger('month')->unique();
            $table->json('outdoors');
            $table->json('under_cover');
            $table->timestamps();
        });

        // Seed with the guide the mobile app used to hard-code (grow_now_screen.dart),
        // so the "What can you grow now?" screen looks the same until an admin edits it.
        $guide = [
            1 => [['Garlic', 'Broad beans (mild areas)'], ['Onions from seed', 'Sweet peas', 'Chillies', 'Microgreens']],
            2 => [['Garlic', 'Shallots', 'Broad beans', 'Parsnips (late month)'], ['Tomatoes', 'Chillies', 'Peppers', 'Aubergines', 'Lettuce']],
            3 => [['Onion sets', 'Peas', 'Spinach', 'Radishes', 'Carrots'], ['Tomatoes', 'Cabbage', 'Leeks', 'Celery', 'Herbs']],
            4 => [['Beetroot', 'Carrots', 'Chard', 'Lettuce', 'Potatoes'], ['Courgettes', 'Squash', 'Sweetcorn', 'French beans']],
            5 => [['Runner beans', 'French beans', 'Beetroot', 'Salad leaves'], ['Cucumbers', 'Pumpkins', 'Basil']],
            6 => [['Courgettes', 'Squash', 'Sweetcorn', 'Kale', 'Carrots'], ['Late cucumbers']],
            7 => [['Spring cabbage', 'Chard', 'Turnips', 'Salad leaves'], ['Oriental greens']],
            8 => [['Spring onions', 'Spinach', 'Radishes', 'Winter salads'], ['Overwintering lettuce']],
            9 => [['Garlic', 'Onion sets (overwintering)', 'Spring cabbage'], ['Winter salads', 'Microgreens']],
            10 => [['Garlic', 'Broad beans', 'Hardy peas'], ['Sweet peas', 'Microgreens']],
            11 => [['Garlic', 'Broad beans', 'Bare-root fruit trees'], ['Microgreens', 'Pea shoots']],
            12 => [['Bare-root fruit trees and bushes'], ['Microgreens', 'Onions from seed (late month)']],
        ];

        DB::table('sowing_guide_months')->insert(
            collect($guide)->map(fn (array $lists, int $month) => [
                'month' => $month,
                'outdoors' => json_encode($lists[0]),
                'under_cover' => json_encode($lists[1]),
                'created_at' => now(),
                'updated_at' => now(),
            ])->values()->all(),
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('sowing_guide_months');
    }
};
