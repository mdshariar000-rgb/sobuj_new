<?php

namespace App\Enums;

enum TransactionType: string
{
    case Swap = 'swap';
    case Free = 'free';
    case Sell = 'sell';
    case SwapOrCash = 'swap_or_cash';

    /** A "wanted" listing — the poster is looking to acquire something, not offering it. */
    case Wanted = 'wanted';

    public function label(): string
    {
        return match ($this) {
            self::Swap => 'Swap',
            self::Free => 'Free',
            self::Sell => 'Sell',
            self::SwapOrCash => 'Swap or Cash',
            self::Wanted => 'Looking to Buy',
        };
    }

    /**
     * Whether listings of this transaction type must carry a price. Mirrors the
     * chk_listings_price_required_for_paid_transaction DB constraint.
     */
    public function requiresPrice(): bool
    {
        return match ($this) {
            self::Sell, self::SwapOrCash => true,
            self::Swap, self::Free, self::Wanted => false,
        };
    }

    /** Wanted listings have no photos — they're a request, not an offer. */
    public function isRequest(): bool
    {
        return $this === self::Wanted;
    }
}
