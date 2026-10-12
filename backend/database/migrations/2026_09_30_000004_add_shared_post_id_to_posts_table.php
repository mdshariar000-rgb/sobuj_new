<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * A share is an ordinary Home Feed post (the sharer's optional caption in
     * body) that embeds another post. shared_post_id goes null if the
     * original is deleted; is_share stays true so the app can still say
     * "this post is no longer available" instead of showing a bare caption.
     */
    public function up(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            $table->boolean('is_share')->default(false)->after('image_path');
            $table->foreignId('shared_post_id')->nullable()->after('is_share')
                ->constrained('posts')->nullOnDelete();
        });
    }

    public function down(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            $table->dropConstrainedForeignId('shared_post_id');
            $table->dropColumn('is_share');
        });
    }
};
