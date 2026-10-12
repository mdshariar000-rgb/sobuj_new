<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('groups', function (Blueprint $table) {
            // Groups the app makes itself (see AutoGroupService) have no
            // human creator — nobody but site admins should manage them.
            $table->foreignId('created_by')->nullable()->change();

            // location / interest / growing_setup / experience_level, plus
            // the value it was made for (e.g. "leeds", "allotment").
            $table->string('auto_type', 30)->nullable()->after('visibility');
            $table->string('auto_key')->nullable()->after('auto_type');
            $table->unique(['auto_type', 'auto_key']);
        });

        Schema::create('group_requests', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('name');
            $table->text('description')->nullable();
            $table->enum('status', ['pending', 'approved', 'declined'])->default('pending');
            $table->timestamps();

            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('group_requests');

        Schema::table('groups', function (Blueprint $table) {
            $table->dropUnique(['auto_type', 'auto_key']);
            $table->dropColumn(['auto_type', 'auto_key']);
        });
    }
};
