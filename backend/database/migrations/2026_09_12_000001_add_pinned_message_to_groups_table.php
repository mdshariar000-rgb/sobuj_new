<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('groups', function (Blueprint $table) {
            $table->text('pinned_message')->nullable()->after('cover_image_path');
            $table->foreignId('pinned_by')->nullable()->after('pinned_message')
                ->constrained('users')->nullOnDelete();
            $table->timestamp('pinned_at')->nullable()->after('pinned_by');
        });
    }

    public function down(): void
    {
        Schema::table('groups', function (Blueprint $table) {
            $table->dropConstrainedForeignId('pinned_by');
            $table->dropColumn(['pinned_message', 'pinned_at']);
        });
    }
};
