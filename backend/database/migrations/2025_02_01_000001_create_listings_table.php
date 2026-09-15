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
        Schema::create('listings', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();

            $table->string('title');
            $table->string('variety')->nullable();

            $table->enum('listing_type', [
                'seed',
                'seedling',
                'cuttings',
                'potted_plant',
            ]);

            $table->enum('transaction_type', [
                'swap',
                'free',
                'sell',
                'swap_or_cash',
            ]);

            $table->decimal('price', 8, 2)->unsigned()->nullable();

            $table->enum('status', [
                'active',
                'reserved',
                'completed',
                'deleted',
            ])->default('active');

            $table->text('looking_for')->nullable();

            // Snapshot of where the listing is pickup-able. Usually mirrors the owning
            // user's location at creation time, but kept independent so a listing can be
            // posted from a different spot (campus, market stall, etc.) without mutating
            // the user's own record. Exact value, never exposed via the API.
            //
            // NOT NULL by requirement: InnoDB rejects NULL in a SPATIAL-indexed column
            // (error 1252), so fuzzy_location below cannot be nullable — every listing
            // must be creatable to a real point, which is inherent to a hyper-local
            // marketplace anyway. Populate both via HasFuzzyLocation::setLocation()
            // before the initial save().
            $table->geometry('base_location', subtype: 'point', srid: 4326);

            // Fuzzed counterpart of base_location — the only coordinate pair safe to
            // return from listing endpoints or plot on a map. See HasFuzzyLocation.
            $table->geometry('fuzzy_location', subtype: 'point', srid: 4326);

            $table->timestamps();

            $table->index(['status', 'listing_type']);
            $table->spatialIndex('fuzzy_location');
        });

        // Data-integrity safety net: a monetary transaction type must carry a price.
        // Enforced again at the FormRequest layer, but pinned here so no code path
        // (queued jobs, admin panel, future services) can silently create an invalid row.
        DB::statement(<<<'SQL'
            ALTER TABLE listings
            ADD CONSTRAINT chk_listings_price_required_for_paid_transaction
            CHECK (
                transaction_type NOT IN ('sell', 'swap_or_cash')
                OR price IS NOT NULL
            )
        SQL);
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('listings');
    }
};
