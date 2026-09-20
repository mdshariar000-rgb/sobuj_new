<?php

namespace App\Models;

use Database\Factories\DeviceTokenFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One row per physical device/FCM token — a user can have several (multiple
 * devices signed in). Always written via updateOrCreate() keyed on `token`
 * alone (see the migration for why), never mass-assigned from raw request
 * input beyond the validated allowlist in DeviceTokenController.
 */
class DeviceToken extends Model
{
    /** @use HasFactory<DeviceTokenFactory> */
    use HasFactory;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'user_id',
        'token',
        'platform',
        'device_id',
        'app_version',
        'last_used_at',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'last_used_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<User, DeviceToken>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
