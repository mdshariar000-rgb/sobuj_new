<?php

namespace App\Models;

use App\Enums\NotificationType;
use Database\Factories\AppNotificationFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * The app's real in-app notification inbox — deliberately not named
 * Notification/notifications, since User already `use`s
 * Illuminate\Notifications\Notifiable, which expects Laravel's own
 * polymorphic notifications table. That trait is otherwise unused anywhere
 * in this app; this model is a separate, purpose-built one.
 *
 * Every field here is system-written by NotificationService — via direct
 * attribute assignment, not create()/update() — and there is no create/update
 * endpoint anywhere that forwards request input into this model, so
 * $fillable staying populated (for the factory to work) never reopens the
 * kind of mass-assignment gap Post::approval_status/Group::status guard
 * against elsewhere in this app.
 */
class AppNotification extends Model
{
    /** @use HasFactory<AppNotificationFactory> */
    use HasFactory;

    protected $table = 'app_notifications';

    /**
     * @var list<string>
     */
    protected $fillable = [
        'recipient_id',
        'actor_id',
        'type',
        'title',
        'body',
        'data',
        'read_at',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'type' => NotificationType::class,
            'data' => 'array',
            'read_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<User, AppNotification>
     */
    public function recipient(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recipient_id');
    }

    /**
     * Null is reserved for a future system-generated notification with no
     * human actor — every trigger wired up so far always has one.
     *
     * @return BelongsTo<User, AppNotification>
     */
    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_id');
    }
}
