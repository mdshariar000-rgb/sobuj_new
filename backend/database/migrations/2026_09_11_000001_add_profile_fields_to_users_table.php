<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('avatar_path')->nullable()->after('name');
            $table->string('cover_photo_path')->nullable()->after('avatar_path');
            $table->string('username')->nullable()->unique()->after('cover_photo_path');
            $table->text('bio')->nullable()->after('username');
            $table->string('phone')->nullable()->after('bio');

            // Free-text label the user types themselves (e.g. "Napa Valley, CA") —
            // no reverse-geocoding exists, so this is never derived from
            // base_location/fuzzy_location.
            $table->string('location_label')->nullable()->after('phone');

            // A short personal list, not a moderated/searchable tag catalog — the
            // user adds/removes their own free-text strings.
            $table->json('growing_interests')->nullable()->after('location_label');

            // Real effect (see ListingResource): when false, this user's own
            // listings stop exposing fuzzy location/distance to other viewers.
            $table->boolean('show_handover_radius')->default(true)->after('growing_interests');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'avatar_path',
                'cover_photo_path',
                'username',
                'bio',
                'phone',
                'location_label',
                'growing_interests',
                'show_handover_radius',
            ]);
        });
    }
};
