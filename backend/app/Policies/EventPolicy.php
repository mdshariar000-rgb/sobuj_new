<?php

namespace App\Policies;

use App\Models\Event;
use App\Models\User;

class EventPolicy
{
    public function before(User $user, string $ability): ?bool
    {
        return $user->is_admin ? true : null;
    }

    public function update(User $user, Event $event): bool
    {
        return $user->id === $event->host_id;
    }

    public function delete(User $user, Event $event): bool
    {
        return $user->id === $event->host_id;
    }
}
