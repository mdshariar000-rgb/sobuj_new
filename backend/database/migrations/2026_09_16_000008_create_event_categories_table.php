<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('event_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->timestamps();
        });

        // A starter set an admin can edit/add to/remove from at any time via
        // the admin panel — matches the event-type language already used
        // around the Events tab (the calendar/filter chips), rather than
        // crop-focus topics (those stay a separate, ungoverned concept).
        DB::table('event_categories')->insert(
            collect([
                'Field Day & Farm Tour',
                'Workshop',
                'Webinar & Online Class',
                'Volunteer Day',
                'Meetup & Social',
                'Conference & Training',
            ])->map(fn ($name) => [
                'name' => $name,
                'created_at' => now(),
                'updated_at' => now(),
            ])->all(),
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('event_categories');
    }
};
