<?php

namespace App\Enums;

enum ReportReason: string
{
    case Spam = 'spam';
    case Inappropriate = 'inappropriate';
    case Harassment = 'harassment';
    case Misleading = 'misleading';
    case Illegal = 'illegal';
    case Other = 'other';

    public function label(): string
    {
        return match ($this) {
            self::Spam => 'Spam',
            self::Inappropriate => 'Inappropriate or offensive',
            self::Harassment => 'Harassment or hate',
            self::Misleading => 'Misleading or scam',
            self::Illegal => 'Illegal or banned species',
            self::Other => 'Other',
        };
    }
}
