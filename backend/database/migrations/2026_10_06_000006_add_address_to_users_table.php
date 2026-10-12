<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // The user's full UK address — private: only they and admins see it
        // (see UserResource). Nullable because accounts made before it was
        // required fill it in on their next app open.
        Schema::table('users', function (Blueprint $table) {
            $table->string('address_line1')->nullable()->after('location_label');
            $table->string('address_line2')->nullable()->after('address_line1');
            $table->string('address_city', 100)->nullable()->after('address_line2');
            $table->string('address_county', 100)->nullable()->after('address_city');
            $table->string('address_postcode', 10)->nullable()->after('address_county');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn(['address_line1', 'address_line2', 'address_city', 'address_county', 'address_postcode']);
        });
    }
};
