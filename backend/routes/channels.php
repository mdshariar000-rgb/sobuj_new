<?php

use App\Models\Group;
use App\Models\SwapOffer;
use App\Models\User;
use Illuminate\Support\Facades\Broadcast;

Broadcast::channel('App.Models.User.{id}', function (User $user, int $id) {
    return $user->id === $id;
});

/**
 * Authorizes subscription to a single swap offer's private chat/status channel.
 * Reuses SwapOfferPolicy::view() so "who can see this thread" is defined in exactly
 * one place, shared by the HTTP endpoints and the WebSocket channel auth.
 */
Broadcast::channel('swap.{swapOfferId}', function (User $user, int $swapOfferId) {
    $swapOffer = SwapOffer::with('listing')->find($swapOfferId);

    return $swapOffer !== null && $user->can('view', $swapOffer);
});

/**
 * Authorizes subscription to a group's real-time chat channel. Reuses
 * GroupPolicy::view() (membership check) — same one-source-of-truth
 * rationale as the swap channel above.
 */
Broadcast::channel('group.{groupId}', function (User $user, int $groupId) {
    $group = Group::find($groupId);

    return $group !== null && $user->can('view', $group);
});
