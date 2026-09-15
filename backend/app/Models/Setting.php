<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

/**
 * Admin-managed key/value store for secrets and config that shouldn't require
 * SSH/.env access to change — e.g. the Gemini API key, set from the
 * Filament settings page. Values are encrypted at rest; a DB-stored value
 * always takes priority over its .env counterpart (see AppServiceProvider),
 * with .env staying as the local-dev/initial-setup fallback.
 */
class Setting extends Model
{
    use HasFactory;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'key',
        'value',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'value' => 'encrypted',
        ];
    }

    /**
     * Note: intentionally fetches the model (not ->value('value') on the query
     * builder) — a raw column pluck would bypass the encrypted cast above.
     */
    public static function get(string $key, ?string $default = null): ?string
    {
        return static::query()->where('key', $key)->first()?->value ?? $default;
    }

    public static function set(string $key, ?string $value): void
    {
        static::query()->updateOrCreate(['key' => $key], ['value' => $value]);
    }
}
