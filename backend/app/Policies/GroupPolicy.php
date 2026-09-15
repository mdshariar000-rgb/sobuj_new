<?php

namespace App\Policies;

use App\Enums\GroupMemberRole;
use App\Enums\GroupStatus;
use App\Models\Group;
use App\Models\User;

class GroupPolicy
{
    /**
     * Staff moderating through the Filament admin panel bypass the
     * creator/admin-member checks below entirely, matching ListingPolicy.
     */
    public function before(User $user, string $ability): ?bool
    {
        return $user->is_admin ? true : null;
    }

    /**
     * The group's creator, or any member holding the `admin` pivot role, may
     * update its details or delete it.
     */
    public function update(User $user, Group $group): bool
    {
        return $this->manages($user, $group);
    }

    public function delete(User $user, Group $group): bool
    {
        return $this->manages($user, $group);
    }

    /**
     * The group's creator or admin may moderate its join requests and
     * pending posts — same rule as update()/delete(), named separately so
     * those two stay focused on "editing the group's own fields" while this
     * one is reused by GroupJoinRequestController and PostPolicy::moderate().
     */
    public function moderate(User $user, Group $group): bool
    {
        return $this->manages($user, $group);
    }

    /**
     * Any member may view/read the group's real-time chat — shared by the
     * HTTP endpoints and the WebSocket channel auth (routes/channels.php),
     * same as SwapOfferPolicy::view(). A site-admin-deactivated/banned
     * group blocks everyone (staff still get through via before()'s
     * is_admin bypass).
     */
    public function view(User $user, Group $group): bool
    {
        if ($group->status !== GroupStatus::Active) {
            return false;
        }

        return $group->members()->where('user_id', $user->id)->exists();
    }

    /**
     * Same participants as view(); kept separate so a future rule specific
     * to sending (e.g. a muted member) doesn't touch read access.
     */
    public function sendMessage(User $user, Group $group): bool
    {
        return $this->view($user, $group);
    }

    private function manages(User $user, Group $group): bool
    {
        if ($user->id === $group->created_by) {
            return true;
        }

        return $group->members()
            ->wherePivot('user_id', $user->id)
            ->wherePivot('role', GroupMemberRole::Admin)
            ->exists();
    }
}
