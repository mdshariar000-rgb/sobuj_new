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
        Schema::create('events', function (Blueprint $table) {
            $table->id();
            $table->foreignId('host_id')->constrained('users')->cascadeOnDelete();
            $table->foreignId('group_id')->nullable()->constrained()->cascadeOnDelete();

            $table->string('title');
            $table->text('description')->nullable();
            $table->enum('format', ['in_person', 'online', 'hybrid']);
            $table->string('cover_image_path')->nullable();

            // Free-text venue/address — no spatial columns yet; add
            // base_location/fuzzy_location (see HasFuzzyLocation) only once a
            // screen actually needs an events map view.
            $table->string('location')->nullable();

            $table->timestamp('starts_at');
            $table->timestamp('ends_at')->nullable();
            $table->unsignedInteger('capacity')->nullable();

            $table->enum('status', ['draft', 'published', 'canceled'])->default('draft');

            $table->timestamps();

            $table->index(['status', 'starts_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('events');
    }
};
