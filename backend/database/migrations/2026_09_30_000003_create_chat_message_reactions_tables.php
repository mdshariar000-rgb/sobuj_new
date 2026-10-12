<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Emoji reactions on chat messages — one per person per message (picking a
 * different emoji replaces it). One table per chat kind so each keeps a real
 * foreign key to its own message table, and reactions vanish with their
 * message or their user.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('message_reactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('message_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('emoji', 16);
            $table->timestamps();

            $table->unique(['message_id', 'user_id']);
        });

        Schema::create('group_message_reactions', function (Blueprint $table) {
            $table->id();
            $table->foreignId('group_message_id')->constrained()->cascadeOnDelete();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('emoji', 16);
            $table->timestamps();

            $table->unique(['group_message_id', 'user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('group_message_reactions');
        Schema::dropIfExists('message_reactions');
    }
};
