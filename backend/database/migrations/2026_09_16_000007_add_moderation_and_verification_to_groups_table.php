<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('groups', function (Blueprint $table) {
            // Site-wide admin takedown state — unrelated to the existing
            // `visibility` (public/private) field, which is a user-facing
            // privacy setting, not moderation. See GroupStatus.
            $table->enum('status', ['active', 'deactivated', 'banned'])
                ->default('active')
                ->after('visibility');
            $table->text('moderation_reason')->nullable()->after('status');
            $table->timestamp('verified_at')->nullable()->after('moderation_reason');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::table('groups', function (Blueprint $table) {
            $table->dropIndex(['status']);
            $table->dropColumn(['status', 'moderation_reason', 'verified_at']);
        });
    }
};
