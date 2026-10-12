<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Lets a chat message carry several photos. `image_path` stays and keeps
 * holding the first photo, so older app builds (which only read
 * `image_url`) still show something; `image_paths` holds all of them.
 */
return new class extends Migration
{
    public function up(): void
    {
        foreach (['messages', 'group_messages'] as $table) {
            Schema::table($table, function (Blueprint $table) {
                $table->json('image_paths')->nullable()->after('image_path');
            });
        }
    }

    public function down(): void
    {
        foreach (['messages', 'group_messages'] as $table) {
            Schema::table($table, function (Blueprint $table) {
                $table->dropColumn('image_paths');
            });
        }
    }
};
