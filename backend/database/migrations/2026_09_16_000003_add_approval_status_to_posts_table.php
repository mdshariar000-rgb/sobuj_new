<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            $table->enum('approval_status', ['approved', 'pending', 'rejected'])
                ->default('approved')
                ->after('group_id');
            $table->index(['group_id', 'approval_status']);
        });
    }

    public function down(): void
    {
        Schema::table('posts', function (Blueprint $table) {
            $table->dropIndex(['group_id', 'approval_status']);
            $table->dropColumn('approval_status');
        });
    }
};
