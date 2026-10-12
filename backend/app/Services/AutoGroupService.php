<?php

namespace App\Services;

use Illuminate\Support\Str;

/**
 * Helpers for the groups the app used to make itself at sign-up (town,
 * interests, growing setup, experience level). Sign-up no longer creates or
 * joins any group — new users are shown groups for their city instead (see
 * GroupController::suggested()). The groups made earlier still exist and keep
 * their auto_type/auto_key, so they're described by these constants.
 */
class AutoGroupService
{
    public const TYPE_LOCATION = 'location';

    public const TYPE_INTEREST = 'interest';

    public const TYPE_GROWING_SETUP = 'growing_setup';

    public const TYPE_EXPERIENCE = 'experience_level';

    /** The last part of a location label when it's only the country. */
    private const COUNTRIES = ['england', 'scotland', 'wales', 'northern ireland', 'united kingdom', 'uk'];

    /**
     * The town or city from a location label like "Headingley, Leeds,
     * England" or "LS6 3AA, Headingley, Leeds, England" — the last part
     * once the country is dropped.
     */
    public static function townFrom(?string $label): ?string
    {
        $parts = array_values(array_filter(
            array_map('trim', explode(',', (string) $label)),
            fn (string $part) => $part !== '',
        ));

        while (count($parts) > 1 && in_array(Str::lower(end($parts)), self::COUNTRIES, true)) {
            array_pop($parts);
        }

        return $parts === [] ? null : end($parts);
    }
}
