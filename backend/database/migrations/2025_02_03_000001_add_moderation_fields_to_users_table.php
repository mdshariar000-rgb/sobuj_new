<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            // Gates access to the Filament admin panel — see User::canAccessPanel().
            // Deliberately separate from being a "verified" or trustworthy consumer
            // account: this is staff-only.
            $table->boolean('is_admin')->default(false)->after('rating_avg');

            $table->boolean('is_suspended')->default(false)->after('is_admin');
            $table->text('suspension_reason')->nullable()->after('is_suspended');

            // Manual identity/trust verification by staff — distinct from
            // email_verified_at, which only proves control of the email address.
            $table->timestamp('verified_at')->nullable()->after('suspension_reason');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['is_admin', 'is_suspended', 'suspension_reason', 'verified_at']);
        });
    }
};
