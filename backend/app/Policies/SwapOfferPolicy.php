<?php

namespace App\Policies;

use App\Enums\SwapOfferStatus;
use App\Models\SwapOffer;
use App\Models\User;

class SwapOfferPolicy
{
    /**
     * Either side of the negotiation — the requester, or the owner of the listing the
     * offer was made against — can view the thread and its messages.
     */
    public function view(User $user, SwapOffer $swapOffer): bool
    {
        return $user->id === $swapOffer->requester_id || $user->id === $swapOffer->listing->user_id;
    }

    /**
     * Same participants as view(); kept as a separate policy method (rather than
     * reusing view()) so a future rule specific to sending messages — e.g. blocking a
     * declined/canceled thread — can be added without touching viewing rights.
     */
    public function sendMessage(User $user, SwapOffer $swapOffer): bool
    {
        return $this->view($user, $swapOffer);
    }

    /**
     * Whether $user may move $swapOffer from its current status to $newStatus.
     *
     * State machine (only path this schema's single `countered` status supports — see
     * Phase 3 notes: one counter-offer round trip, not open-ended back-and-forth):
     *
     *   pending   --owner-->    accepted | declined | countered
     *   pending   --requester--> canceled
     *   countered --requester--> accepted | declined
     *   countered --owner-->     canceled
     *   accepted  --either-->    completed | canceled
     *   completed / declined / canceled: terminal, no further transitions.
     */
    public function respond(User $user, SwapOffer $swapOffer, SwapOfferStatus $newStatus): bool
    {
        $isOwner = $user->id === $swapOffer->listing->user_id;
        $isRequester = $user->id === $swapOffer->requester_id;

        if (! $isOwner && ! $isRequester) {
            return false;
        }

        return match ($swapOffer->status) {
            SwapOfferStatus::Pending => $isOwner
                ? in_array($newStatus, [SwapOfferStatus::Accepted, SwapOfferStatus::Declined, SwapOfferStatus::Countered], true)
                : ($isRequester && $newStatus === SwapOfferStatus::Canceled),

            SwapOfferStatus::Countered => $isRequester
                ? in_array($newStatus, [SwapOfferStatus::Accepted, SwapOfferStatus::Declined], true)
                : ($isOwner && $newStatus === SwapOfferStatus::Canceled),

            SwapOfferStatus::Accepted => in_array($newStatus, [SwapOfferStatus::Completed, SwapOfferStatus::Canceled], true),

            SwapOfferStatus::Declined, SwapOfferStatus::Completed, SwapOfferStatus::Canceled => false,
        };
    }
}
