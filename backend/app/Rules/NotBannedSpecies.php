<?php

namespace App\Rules;

use App\Models\BannedSpecies;
use Closure;
use Illuminate\Contracts\Validation\ValidationRule;

/**
 * Rejects a value that contains a banned/invasive species name anywhere in it (e.g. a
 * listing titled "Fast-growing Japanese Knotweed cuttings" is caught even though the
 * banned_species row is just "Japanese Knotweed") — a whole-value exact match would
 * essentially never fire, since listing titles are free text, not species names.
 */
class NotBannedSpecies implements ValidationRule
{
    /**
     * Banned names shorter than this are ignored as a substring match, since a very
     * short entry (e.g. a 1-2 character typo in the admin panel) would otherwise match
     * almost any listing title.
     */
    private const MIN_MATCHABLE_LENGTH = 3;

    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        if (! is_string($value) || trim($value) === '') {
            return;
        }

        $match = BannedSpecies::query()
            ->whereRaw('LENGTH(name) >= ?', [self::MIN_MATCHABLE_LENGTH])
            ->whereRaw('LOWER(?) LIKE CONCAT(\'%\', LOWER(name), \'%\')', [$value])
            ->value('name');

        if ($match !== null) {
            $fail("The :attribute cannot reference \"{$match}\", which is a banned or invasive species.");
        }
    }
}
