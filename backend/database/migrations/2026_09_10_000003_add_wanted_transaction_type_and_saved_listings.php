<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        // Native MySQL ENUM column — Laravel's schema builder can't append a value
        // to an existing enum list, so this modifies the column definition directly.
        DB::statement(
            'ALTER TABLE listings MODIFY COLUMN transaction_type '.
            "ENUM('swap', 'free', 'sell', 'swap_or_cash', 'wanted') NOT NULL"
        );

        Schema::create('saved_listings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('listing_id')->constrained()->cascadeOnDelete();
            $table->timestamp('created_at')->useCurrent();

            $table->unique(['user_id', 'listing_id']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('saved_listings');

        DB::statement(
            'ALTER TABLE listings MODIFY COLUMN transaction_type '.
            "ENUM('swap', 'free', 'sell', 'swap_or_cash') NOT NULL"
        );
    }
};
