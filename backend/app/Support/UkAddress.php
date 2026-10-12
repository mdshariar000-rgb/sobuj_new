<?php

namespace App\Support;

/**
 * Validation rules and clean-up for a user's UK address (users.address_*).
 */
final class UkAddress
{
    /** Any valid UK postcode format, e.g. "LS6 3AA", "SW1A 1AA", "M1 1AE". */
    public const POSTCODE_PATTERN = '/^(GIR 0AA|[A-PR-UWYZ][A-HK-Y]?[0-9][0-9A-HJKMNPR-Y]? [0-9][ABD-HJLNP-UW-Z]{2})$/';

    public const FIELDS = ['address_line1', 'address_line2', 'address_city', 'address_county', 'address_postcode'];

    /** "ls63aa" / "LS6  3AA" → "LS6 3AA". */
    public static function normalisePostcode(?string $postcode): ?string
    {
        if ($postcode === null) {
            return null;
        }

        $compact = strtoupper(preg_replace('/\s+/', '', $postcode));

        return strlen($compact) > 3
            ? substr($compact, 0, -3).' '.substr($compact, -3)
            : $compact;
    }

    /**
     * @param  bool  $required  True at sign-up; false for profile edits,
     *                          where each field is only checked if sent.
     * @return array<string, list<mixed>>
     */
    public static function rules(bool $required): array
    {
        $presence = $required ? ['required'] : ['sometimes', 'required'];

        return [
            'address_line1' => [...$presence, 'string', 'max:255'],
            'address_line2' => ['sometimes', 'nullable', 'string', 'max:255'],
            'address_city' => [...$presence, 'string', 'max:100'],
            'address_county' => ['sometimes', 'nullable', 'string', 'max:100'],
            'address_postcode' => [...$presence, 'string', 'regex:'.self::POSTCODE_PATTERN],
        ];
    }
}
