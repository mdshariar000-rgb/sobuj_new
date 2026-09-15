<?php

namespace App\Enums;

/**
 * Site-wide admin takedown state — unrelated to GroupVisibility (public/
 * private), which is a user-facing privacy setting a group's own admin
 * controls, not moderation.
 */
enum GroupStatus: string
{
    case Active = 'active';
    case Deactivated = 'deactivated';
    case Banned = 'banned';

    public function label(): string
    {
        return match ($this) {
            self::Active => 'Active',
            self::Deactivated => 'Deactivated',
            self::Banned => 'Banned',
        };
    }
}
