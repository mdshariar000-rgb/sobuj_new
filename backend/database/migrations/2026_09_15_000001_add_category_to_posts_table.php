<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            $table->enum('category', ['general', 'disease_alert', 'harvest'])
                ->default('general')
                ->after('body');
            $table->index(['group_id', 'category']);
        });
    }

    public function down(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            $table->dropIndex(['group_id', 'category']);
            $table->dropColumn('category');
        });
    }
};
