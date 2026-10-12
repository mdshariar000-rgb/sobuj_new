<?php

namespace App\Support;

use App\Models\Setting;
use Throwable;

/**
 * "Sign in with Google / Apple" credentials, set on the admin Settings page.
 * The app reads the public parts (GET /config/social) so the ids can change
 * without a new app build; the Apple private key never leaves the server.
 */
final class SocialSettings
{
    public const GOOGLE_ENABLED = 'google_enabled';

    public const GOOGLE_IOS_CLIENT_ID = 'google_ios_client_id';

    public const GOOGLE_SERVER_CLIENT_ID = 'google_server_client_id';

    /** Any other client ids whose tokens to accept, one per line. */
    public const GOOGLE_EXTRA_CLIENT_IDS = 'google_client_ids';

    public const APPLE_ENABLED = 'apple_enabled';

    public const APPLE_CLIENT_ID = 'apple_client_id';

    public const APPLE_TEAM_ID = 'apple_team_id';

    public const APPLE_KEY_ID = 'apple_key_id';

    public const APPLE_PRIVATE_KEY = 'apple_private_key';

    public const KEYS = [
        self::GOOGLE_ENABLED, self::GOOGLE_IOS_CLIENT_ID, self::GOOGLE_SERVER_CLIENT_ID, self::GOOGLE_EXTRA_CLIENT_IDS,
        self::APPLE_ENABLED, self::APPLE_CLIENT_ID, self::APPLE_TEAM_ID, self::APPLE_KEY_ID, self::APPLE_PRIVATE_KEY,
    ];

    /** @return array<string, ?string> */
    public static function all(): array
    {
        try {
            $rows = Setting::query()->whereIn('key', self::KEYS)->get()->pluck('value', 'key');
        } catch (Throwable) {
            $rows = collect();
        }

        return collect(self::KEYS)->mapWithKeys(fn ($key) => [$key => $rows[$key] ?? null])->all();
    }

    /** Off until switched on in Settings (and its ids are filled in). */
    public static function googleEnabled(array $s): bool
    {
        return ($s[self::GOOGLE_ENABLED] ?? null) === '1' && self::googleClientIds($s) !== [];
    }

    /** Off until switched on — Apple must be enabled for the App ID first. */
    public static function appleEnabled(array $s): bool
    {
        return ($s[self::APPLE_ENABLED] ?? null) === '1' && self::appleClientId($s) !== null;
    }

    /** @return list<string> every Google client id a token may be issued for */
    public static function googleClientIds(array $s): array
    {
        $ids = implode("\n", array_filter([
            $s[self::GOOGLE_IOS_CLIENT_ID] ?? null,
            $s[self::GOOGLE_SERVER_CLIENT_ID] ?? null,
            $s[self::GOOGLE_EXTRA_CLIENT_IDS] ?? null,
            config('services.google.client_ids'),
        ]));

        return array_values(array_unique(array_filter(array_map('trim', preg_split('/[\s,]+/', $ids) ?: []))));
    }

    /** The app's bundle id (native iOS sign-in issues tokens for it). */
    public static function appleClientId(array $s): ?string
    {
        return ($s[self::APPLE_CLIENT_ID] ?? null) ?: (config('services.apple.client_id') ?: null);
    }

    /** True when the key for revoking Apple sign-ins (on account deletion) is set. */
    public static function appleKeyConfigured(array $s): bool
    {
        return filled($s[self::APPLE_TEAM_ID] ?? null)
            && filled($s[self::APPLE_KEY_ID] ?? null)
            && filled($s[self::APPLE_PRIVATE_KEY] ?? null);
    }
}
