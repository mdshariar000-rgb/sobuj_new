<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('device_tokens', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            // Unique on the token alone (not user_id+token) — if the same
            // physical token later registers under a different account (a
            // shared device, or someone logging in as someone else on it),
            // this row's user_id reassigns to the new owner so the old
            // owner stops receiving that device's pushes.
            $table->string('token')->unique();
            $table->string('platform', 16)->default('android');
            $table->string('device_id')->nullable();
            $table->string('app_version', 32)->nullable();
            $table->timestamp('last_used_at')->nullable();
            $table->timestamps();

            $table->index('user_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('device_tokens');
    }
};
