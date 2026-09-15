<?php

namespace App\Enums;

enum SwapOfferStatus: string
{
    case Pending = 'pending';
    case Countered = 'countered';
    case Accepted = 'accepted';
    case Declined = 'declined';
    case Completed = 'completed';
    case Canceled = 'canceled';

    public function label(): string
    {
        return match ($this) {
            self::Pending => 'Pending',
            self::Countered => 'Countered',
            self::Accepted => 'Accepted',
            self::Declined => 'Declined',
            self::Completed => 'Completed',
            self::Canceled => 'Canceled',
        };
    }

    /**
     * Whether this is a terminal state — Accepted still awaits a real-world handover
     * before it can become Completed, so it is not terminal.
     */
    public function isFinal(): bool
    {
        return match ($this) {
            self::Declined, self::Completed, self::Canceled => true,
            self::Pending, self::Countered, self::Accepted => false,
        };
    }
}
