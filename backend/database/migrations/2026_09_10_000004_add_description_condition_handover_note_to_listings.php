<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('listings', function (Blueprint $table) {
            // Free-text detail, distinct from the short `title` — the Create Listing
            // screen's "Detailed Description" field.
            $table->text('description')->nullable()->after('variety');
            $table->string('condition')->nullable()->after('description');
            // Free-text handover instructions (pickup spot, drop-off, shipping, etc.)
            // rather than fixed mode flags — the app has no delivery/shipping
            // infrastructure to actually enforce a fixed set of modes.
            $table->text('handover_note')->nullable()->after('looking_for');
        });
    }

    public function down(): void
    {
        Schema::table('listings', function (Blueprint $table) {
            $table->dropColumn(['description', 'condition', 'handover_note']);
        });
    }
};
