<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // Named app_notifications (not notifications) so it never collides
        // with Laravel's own polymorphic notifications table — User already
        // `use`s Illuminate\Notifications\Notifiable, but nothing calls
        // ->notify() anywhere in this app; that trait stays dormant.
        Schema::create('app_notifications', function (Blueprint $table) {
            $table->id();
            $table->foreignId('recipient_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('actor_id')->nullable()->constrained('users')->nullOnDelete();
            $table->string('type', 32);
            $table->string('title');
            $table->string('body', 500);
            // Deep-link payload — shape varies by type (post_id/comment_id,
            // swap_offer_id, group_id, etc.), read by the mobile app to
            // route a tapped notification to the right screen.
            $table->json('data')->nullable();
            $table->timestamp('read_at')->nullable();
            $table->timestamps();

            $table->index(['recipient_id', 'created_at']);
            $table->index(['recipient_id', 'read_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('app_notifications');
    }
};
