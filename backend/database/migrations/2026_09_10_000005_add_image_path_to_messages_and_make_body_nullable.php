<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('messages', function (Blueprint $table) {
            $table->string('image_path')->nullable()->after('body');
        });

        // A message can now be image-only — raw SQL rather than the schema builder's
        // ->change() to avoid a doctrine/dbal dependency, matching the rest of this
        // codebase's approach to column-type changes (see the transaction_type ENUM
        // migration).
        DB::statement('ALTER TABLE messages MODIFY body TEXT NULL');
    }

    public function down(): void
    {
        DB::statement("UPDATE messages SET body = '' WHERE body IS NULL");
        DB::statement('ALTER TABLE messages MODIFY body TEXT NOT NULL');

        Schema::table('messages', function (Blueprint $table) {
            $table->dropColumn('image_path');
        });
    }
};
