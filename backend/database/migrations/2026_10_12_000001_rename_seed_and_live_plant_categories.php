<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * Client feedback (2026-10-12): shorter marketplace category names. Moves the
 * existing listings with them — listings.listing_type holds the name, not an
 * id. Skips a rename whose old name is gone or whose new name already exists.
 */
return new class extends Migration
{
    private const RENAMES = [
        'Seeds & Scions' => 'Seed',
        'Live Plants & Saplings' => 'Live plants',
    ];

    public function up(): void
    {
        foreach (self::RENAMES as $from => $to) {
            $this->rename($from, $to);
        }
    }

    public function down(): void
    {
        foreach (self::RENAMES as $from => $to) {
            $this->rename($to, $from);
        }
    }

    private function rename(string $from, string $to): void
    {
        DB::transaction(function () use ($from, $to) {
            $exists = DB::table('listing_categories')->where('name', $from)->exists();
            $taken = DB::table('listing_categories')->where('name', $to)->exists();
            if (! $exists || $taken) {
                return;
            }

            DB::table('listing_categories')->where('name', $from)->update(['name' => $to, 'updated_at' => now()]);
            DB::table('listings')->where('listing_type', $from)->update(['listing_type' => $to]);
        });
    }
};
