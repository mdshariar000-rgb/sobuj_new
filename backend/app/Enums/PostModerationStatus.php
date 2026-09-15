<?php

namespace App\Enums;

/**
 * Site-wide admin moderation state — entirely separate from
 * PostApprovalStatus, which is group-admin-only and doesn't affect Home
 * Feed visibility. See PostPolicy::view().
 */
enum PostModerationStatus: string
{
    case Visible = 'visible';
    case Deactivated = 'deactivated';
    case Banned = 'banned';

    public function label(): string
    {
        return match ($this) {
            self::Visible => 'Visible',
            self::Deactivated => 'Deactivated',
            self::Banned => 'Banned',
        };
    }
}
