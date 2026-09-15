<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * An admin-managed event category — the mobile app's "create an event" form
 * picks from this list rather than typing free text, and StoreEventRequest/
 * UpdateEventRequest validate against it by name (not a foreign key on
 * events.category, so existing events keep whatever category they already
 * had even if it's later removed from this list).
 */
class EventCategory extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'name',
    ];
}
