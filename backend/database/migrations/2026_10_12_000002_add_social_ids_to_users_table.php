<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * "Sign in with Google / Apple": each provider's stable account id (the
 * token's `sub`), so a later sign-in finds the same account even if the
 * email on it changes. `has_password` is false for an account made that
 * way until "Forgot password?" sets one — deleting it then confirms with
 * the provider instead of a password.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->string('google_id')->nullable()->unique()->after('email');
            $table->string('apple_id')->nullable()->unique()->after('google_id');
            $table->boolean('has_password')->default(true)->after('password');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropUnique(['google_id']);
            $table->dropUnique(['apple_id']);
            $table->dropColumn(['google_id', 'apple_id', 'has_password']);
        });
    }
};
