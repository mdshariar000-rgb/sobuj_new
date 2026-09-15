<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('post_categories', function (Blueprint $table) {
            $table->id();
            $table->string('name')->unique();
            $table->timestamps();
        });

        // "General" is the app's built-in fallback — PostController::store()
        // assigns it to any post that doesn't pick a category, so it must
        // always exist. Admins can rename it but shouldn't delete it.
        DB::table('post_categories')->insert(
            collect(['General', 'Disease Alert', 'Harvest'])->map(fn ($name) => [
                'name' => $name,
                'created_at' => now(),
                'updated_at' => now(),
            ])->all(),
        );

        // posts.category was a native MySQL ENUM(general, disease_alert,
        // harvest) — widen it to a plain string so it can hold any
        // admin-managed category name, then remap the existing rows' short
        // codes onto their matching real names above.
        DB::statement("ALTER TABLE posts MODIFY COLUMN category VARCHAR(255) NOT NULL DEFAULT 'General'");

        DB::table('posts')->where('category', 'general')->update(['category' => 'General']);
        DB::table('posts')->where('category', 'disease_alert')->update(['category' => 'Disease Alert']);
        DB::table('posts')->where('category', 'harvest')->update(['category' => 'Harvest']);
    }

    public function down(): void
    {
        DB::table('posts')->where('category', 'General')->update(['category' => 'general']);
        DB::table('posts')->where('category', 'Disease Alert')->update(['category' => 'disease_alert']);
        DB::table('posts')->where('category', 'Harvest')->update(['category' => 'harvest']);

        DB::statement("ALTER TABLE posts MODIFY COLUMN category ENUM('general', 'disease_alert', 'harvest') NOT NULL DEFAULT 'general'");

        Schema::dropIfExists('post_categories');
    }
};
