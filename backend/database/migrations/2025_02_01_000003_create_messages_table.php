<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('messages', function (Blueprint $table) {
            $table->id();
            $table->foreignId('swap_offer_id')->constrained()->cascadeOnDelete();

            // Nullable so purely automated system_event rows (e.g. "offer expired") can
            // be recorded without an acting user, and so the message survives its
            // original sender deleting their account.
            $table->foreignId('sender_id')->nullable()->constrained('users')->nullOnDelete();

            $table->enum('message_type', ['text', 'system_event'])->default('text');
            $table->text('body');

            $table->timestamps();

            $table->index(['swap_offer_id', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('messages');
    }
};
