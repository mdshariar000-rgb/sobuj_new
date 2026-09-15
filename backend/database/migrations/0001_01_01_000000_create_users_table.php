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
        Schema::create('users', function (Blueprint $table) {
            $table->id();
            $table->string('name');
            $table->string('email')->unique();
            $table->timestamp('email_verified_at')->nullable();
            $table->string('password');

            // Exact GPS coordinates as reported by the device. Never exposed via the API
            // or any resource/serializer — read only by trusted server-side code (e.g. to
            // recompute fuzzy_location). See App\Models\Concerns\HasFuzzyLocation.
            //
            // NOT NULL by requirement: InnoDB rejects NULL values in a SPATIAL-indexed
            // column (error 1252), so fuzzy_location below cannot be nullable — and since
            // it is always derived from base_location, the two are kept in lockstep as
            // both-required. Location capture is therefore mandatory as part of
            // registration (this is a hyper-local app; an account with no location can't
            // meaningfully use it anyway). Use HasFuzzyLocation::setLocation() to
            // populate both columns together before the initial save().
            $table->geometry('base_location', subtype: 'point', srid: 4326);

            // Publicly discoverable location: base_location offset by a random 500m-1000m
            // vector (see HasFuzzyLocation::applyFuzzyOffset). This is the only location
            // column that should ever be selected into an API response or map pin.
            $table->geometry('fuzzy_location', subtype: 'point', srid: 4326);

            $table->enum('experience_level', [
                'beginner',
                'intermediate',
                'experienced',
                'expert',
            ])->nullable();

            $table->enum('growing_setup', [
                'balcony',
                'indoor',
                'backyard',
                'rooftop',
                'community_garden',
                'greenhouse',
            ])->nullable();

            $table->decimal('rating_avg', 3, 2)->unsigned()->default(0);

            $table->rememberToken();
            $table->timestamps();

            $table->spatialIndex('fuzzy_location');
        });

        Schema::create('password_reset_tokens', function (Blueprint $table) {
            $table->string('email')->primary();
            $table->string('token');
            $table->timestamp('created_at')->nullable();
        });

        Schema::create('sessions', function (Blueprint $table) {
            $table->string('id')->primary();
            $table->foreignId('user_id')->nullable()->index();
            $table->string('ip_address', 45)->nullable();
            $table->text('user_agent')->nullable();
            $table->longText('payload');
            $table->integer('last_activity')->index();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('users');
        Schema::dropIfExists('password_reset_tokens');
        Schema::dropIfExists('sessions');
    }
};
