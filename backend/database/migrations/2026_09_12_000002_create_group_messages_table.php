<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('group_messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('group_id')->constrained()->cascadeOnDelete();

            // Nullable so a message survives its original sender deleting their
            // account — same convention as messages.sender_id.
            $table->foreignId('sender_id')->nullable()->constrained('users')->nullOnDelete();

            $table->text('body')->nullable();
            $table->string('image_path')->nullable();

            $table->timestamps();

            $table->index(['group_id', 'created_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('group_messages');
    }
};
