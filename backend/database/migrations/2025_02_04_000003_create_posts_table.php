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
        Schema::create('posts', function (Blueprint $table) {
            $table->id();
            $table->foreignId('author_id')->constrained('users')->cascadeOnDelete();

            // Null = a general Home Feed community post. Set = posted inside this
            // group's discussion thread. One table serves both, since they're the
            // same shape (author, body, image, comments) — just scoped differently.
            $table->foreignId('group_id')->nullable()->constrained()->cascadeOnDelete();

            $table->text('body');
            $table->string('image_path')->nullable();
            $table->timestamps();

            $table->index(['group_id', 'created_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('posts');
    }
};
