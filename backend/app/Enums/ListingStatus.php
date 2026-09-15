<?php

namespace App\Enums;

enum ListingStatus: string
{
    case Active = 'active';
    case Reserved = 'reserved';
    case Completed = 'completed';
    case Deleted = 'deleted';

    public function label(): string
    {
        return match ($this) {
            self::Active => 'Active',
            self::Reserved => 'Reserved',
            self::Completed => 'Completed',
            self::Deleted => 'Deleted',
        };
    }
}
