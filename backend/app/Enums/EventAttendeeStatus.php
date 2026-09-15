<?php

namespace App\Enums;

enum EventAttendeeStatus: string
{
    case Going = 'going';
    case Interested = 'interested';

    public function label(): string
    {
        return match ($this) {
            self::Going => 'Going',
            self::Interested => 'Interested',
        };
    }
}
