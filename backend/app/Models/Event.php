<?php

namespace App\Models;

use App\Enums\EventFormat;
use App\Enums\EventStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Event extends Model
{
    use HasFactory;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'group_id',
        'title',
        'description',
        'format',
        'category',
        'cover_image_path',
        'location',
        'starts_at',
        'ends_at',
        'capacity',
        'registration_fee',
        'proposed_dates',
        'status',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'format' => EventFormat::class,
            'status' => EventStatus::class,
            'starts_at' => 'datetime',
            'ends_at' => 'datetime',
            'registration_fee' => 'decimal:2',
            'proposed_dates' => 'array',
        ];
    }

    /**
     * @return BelongsTo<User, Event>
     */
    public function host(): BelongsTo
    {
        return $this->belongsTo(User::class, 'host_id');
    }

    /**
     * Null when this event isn't hosted under any particular group.
     *
     * @return BelongsTo<Group, Event>
     */
    public function group(): BelongsTo
    {
        return $this->belongsTo(Group::class);
    }

    /**
     * @return BelongsToMany<User, Event>
     */
    public function attendees(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'event_attendees')
            ->using(EventAttendee::class)
            ->withPivot(['status', 'rsvped_at']);
    }

    /**
     * @return BelongsToMany<User, Event>
     */
    /** The event's hidden chat group — see EventChatService. */
    public function chatGroup(): HasOne
    {
        return $this->hasOne(Group::class);
    }

    public function reviews(): HasMany
    {
        return $this->hasMany(EventReview::class);
    }

    public function savedBy(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'saved_events');
    }
}
