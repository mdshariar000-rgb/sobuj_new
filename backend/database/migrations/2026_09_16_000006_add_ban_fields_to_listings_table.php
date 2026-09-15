<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('listings', function (Blueprint $table) {
            // Distinct from the existing "Deactivate" (status = Deleted, always
            // reversible) — a ban also sets these two, and a Filament "Restore"
            // action is the only way back, same reversible-by-staff-only
            // pattern used everywhere else in the admin panel.
            $table->timestamp('banned_at')->nullable()->after('flagged_reason');
            $table->text('banned_reason')->nullable()->after('banned_at');
        });
    }

    public function down(): void
    {
        Schema::table('listings', function (Blueprint $table) {
            $table->dropColumn(['banned_at', 'banned_reason']);
        });
    }
};
