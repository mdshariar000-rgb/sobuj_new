<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::statement("ALTER TABLE users MODIFY growing_setup ENUM('balcony', 'indoor', 'backyard', 'rooftop', 'community_garden', 'greenhouse', 'allotment') NULL");
    }

    public function down(): void
    {
        DB::table('users')->where('growing_setup', 'allotment')->update(['growing_setup' => null]);
        DB::statement("ALTER TABLE users MODIFY growing_setup ENUM('balcony', 'indoor', 'backyard', 'rooftop', 'community_garden', 'greenhouse') NULL");
    }
};
