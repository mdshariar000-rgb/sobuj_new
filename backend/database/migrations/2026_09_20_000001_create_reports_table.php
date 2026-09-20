<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('reports', function (Blueprint $table) {
            $table->id();
            $table->foreignId('reporter_id')->constrained('users')->cascadeOnDelete();

            // Polymorphic by hand (not morphs()) so the type column stays a short
            // stable slug ('post', 'listing', ...) — see App\Enums\ReportTargetType.
            $table->string('target_type', 32);
            $table->unsignedBigInteger('target_id');

            $table->string('reason', 32);
            $table->string('details', 500)->nullable();
            $table->string('status', 16)->default('pending');

            $table->foreignId('reviewed_by')->nullable()->constrained('users')->nullOnDelete();
            $table->timestamp('reviewed_at')->nullable();

            $table->timestamps();

            // One report per reporter per target — re-reporting is idempotent.
            $table->unique(['reporter_id', 'target_type', 'target_id']);
            $table->index(['status', 'created_at']);
            $table->index(['target_type', 'target_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reports');
    }
};
