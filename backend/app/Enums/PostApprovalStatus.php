<?php

namespace App\Enums;

enum PostApprovalStatus: string
{
    case Approved = 'approved';
    case Pending = 'pending';
    case Rejected = 'rejected';

    public function label(): string
    {
        return match ($this) {
            self::Approved => 'Approved',
            self::Pending => 'Pending Approval',
            self::Rejected => 'Rejected',
        };
    }
}
