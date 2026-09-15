<?php

namespace App\Enums;

/**
 * No Approved case — an approved request is deleted and replaced by a real
 * group_members row rather than ever being stored as a status. See
 * GroupJoinRequestController::update().
 */
enum GroupJoinRequestStatus: string
{
    case Pending = 'pending';
    case Rejected = 'rejected';

    public function label(): string
    {
        return match ($this) {
            self::Pending => 'Pending',
            self::Rejected => 'Rejected',
        };
    }
}
