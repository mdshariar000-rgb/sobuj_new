<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // A message-id watermark rather than a last-read timestamp: two
        // events (a join and a message send) can land in the same wall-clock
        // second at this app's default timestamp precision, which would make
        // a `created_at > last_read_at` comparison wrongly tie. Auto-
        // increment ids have no such tie, so `id > last_read_message_id` is
        // exact regardless of timing. Defaults to 0 (never 0 for a real
        // message) rather than nullable, so a member who hasn't read
        // anything yet still compares cleanly with no null-coalescing needed
        // — see GroupController::index()'s unread_count subquery.
        Schema::table('group_members', function (Blueprint $table) {
            $table->unsignedBigInteger('last_read_message_id')->default(0)->after('joined_at');
        });
    }

    public function down(): void
    {
        Schema::table('group_members', function (Blueprint $table) {
            $table->dropColumn('last_read_message_id');
        });
    }
};
