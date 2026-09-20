<?php

namespace App\Policies;

use App\Models\AppNotification;
use App\Models\User;

class AppNotificationPolicy
{
    public function before(User $user, string $ability): ?bool
    {
        return $user->is_admin ? true : null;
    }

    public function update(User $user, AppNotification $notification): bool
    {
        return $user->id === $notification->recipient_id;
    }
}
