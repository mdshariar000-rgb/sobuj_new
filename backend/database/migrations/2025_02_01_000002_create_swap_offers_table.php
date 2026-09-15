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
        Schema::create('swap_offers', function (Blueprint $table) {
            $table->id();
            $table->foreignId('listing_id')->constrained()->cascadeOnDelete();
            $table->foreignId('requester_id')->constrained('users')->cascadeOnDelete();

            $table->enum('status', [
                'pending',
                'countered',
                'accepted',
                'declined',
                'completed',
                'canceled',
            ])->default('pending');

            // Free-form terms of the offer: what the requester is putting up in exchange
            // (their own listing_id, quantity, cash top-up, notes, etc.). Kept as JSON
            // rather than a rigid schema since offer shapes vary by transaction_type.
            $table->json('offer_details')->nullable();

            $table->timestamps();

            $table->index(['listing_id', 'status']);
            $table->index('requester_id');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('swap_offers');
    }
};
