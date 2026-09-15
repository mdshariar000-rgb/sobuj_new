<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            // Site-wide admin moderation — entirely separate from
            // approval_status, which is group-admin-only and doesn't affect
            // Home Feed posts. See PostModerationStatus / PostPolicy::view().
            $table->enum('moderation_status', ['visible', 'deactivated', 'banned'])
                ->default('visible')
                ->after('approval_status');
            $table->text('moderation_reason')->nullable()->after('moderation_status');
            $table->timestamp('moderated_at')->nullable()->after('moderation_reason');
            $table->foreignId('moderated_by')->nullable()->after('moderated_at')
                ->constrained('users')->nullOnDelete();
            $table->index('moderation_status');
        });
    }

    public function down(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            $table->dropIndex(['moderation_status']);
            $table->dropForeign(['moderated_by']);
            $table->dropColumn(['moderation_status', 'moderation_reason', 'moderated_at', 'moderated_by']);
        });
    }
};
