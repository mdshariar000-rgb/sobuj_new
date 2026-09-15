<?php

namespace App\Models;

use App\Enums\EventAttendeeStatus;
use Illuminate\Database\Eloquent\Relations\Pivot;

/**
 * Pivot model for the events <-> users belongsToMany (see Event::attendees()).
 */
class EventAttendee extends Pivot
{
    /**
     * The event_attendees table has its own auto-incrementing id, unlike
     * Pivot's default composite-key-only assumption.
     *
     * @var bool
     */
    public $incrementing = true;

    /**
     * @var string
     */
    protected $table = 'event_attendees';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'status' => EventAttendeeStatus::class,
            'rsvped_at' => 'datetime',
        ];
    }
}
