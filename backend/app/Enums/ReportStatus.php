<?php

namespace App\Enums;

enum ReportStatus: string
{
    case Pending = 'pending';
    case Actioned = 'actioned';
    case Dismissed = 'dismissed';

    public function label(): string
    {
        return match ($this) {
            self::Pending => 'Pending',
            self::Actioned => 'Action taken',
            self::Dismissed => 'Dismissed',
        };
    }
}
