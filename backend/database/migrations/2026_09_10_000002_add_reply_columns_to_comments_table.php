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
        Schema::table('comments', function (Blueprint $table) {
            // Always points at a top-level comment (never another reply) —
            // replying to a reply flattens into the same thread one level
            // deep, same as Facebook/Instagram, rather than nesting further.
            $table->foreignId('parent_id')->nullable()->after('post_id')
                ->constrained('comments')->cascadeOnDelete();

            // Which specific comment's author this reply is addressing —
            // separate from parent_id so a reply-to-a-reply can still credit
            // the right person in its bold name prefix.
            $table->foreignId('replying_to_user_id')->nullable()->after('author_id')
                ->constrained('users')->nullOnDelete();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('comments', function (Blueprint $table) {
            $table->dropConstrainedForeignId('parent_id');
            $table->dropConstrainedForeignId('replying_to_user_id');
        });
    }
};
