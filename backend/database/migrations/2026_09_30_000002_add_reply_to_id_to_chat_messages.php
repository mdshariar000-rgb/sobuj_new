<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Lets a chat message quote an earlier message in the same thread.
 *
 * Deliberately an indexed column rather than a self-referencing foreign
 * key: the original can be deleted (e.g. its sender deletes their account)
 * while replies to it live on, and the API then just reports the quoted
 * message as unavailable — no cascade rules on a table's own rows needed.
 */
return new class extends Migration
{
    public function up(): void
    {
        foreach (['messages', 'group_messages'] as $table) {
            Schema::table($table, function (Blueprint $table) {
                $table->unsignedBigInteger('reply_to_id')->nullable()->after('image_paths')->index();
            });
        }
    }

    public function down(): void
    {
        foreach (['messages', 'group_messages'] as $table) {
            Schema::table($table, function (Blueprint $table) {
                $table->dropIndex(['reply_to_id']);
                $table->dropColumn('reply_to_id');
            });
        }
    }
};
