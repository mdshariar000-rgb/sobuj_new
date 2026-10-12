<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const NEW_CATEGORIES = ['Open Day', 'Seed Swap', 'Plant Fair', 'Nature Walk', 'Other'];

    public function up(): void
    {
        Schema::table('events', function (Blueprint $table) {
            // Shown to attendees only — paid in person, not through the app.
            $table->decimal('registration_fee', 8, 2)->nullable()->after('capacity');

            // Other dates the host is considering, besides starts_at.
            $table->json('proposed_dates')->nullable()->after('ends_at');
        });

        Schema::create('event_reviews', function (Blueprint $table) {
            $table->id();
            $table->foreignId('event_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            // Optional: a plain comment has no rating.
            $table->unsignedTinyInteger('rating')->nullable();
            $table->text('body')->nullable();
            $table->timestamps();

            $table->index(['event_id', 'created_at']);
        });

        $now = now();
        foreach (self::NEW_CATEGORIES as $name) {
            DB::table('event_categories')->insertOrIgnore([
                'name' => $name,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('event_reviews');

        Schema::table('events', function (Blueprint $table) {
            $table->dropColumn(['registration_fee', 'proposed_dates']);
        });
    }
};
