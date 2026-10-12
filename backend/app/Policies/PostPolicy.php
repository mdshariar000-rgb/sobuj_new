<?php

namespace App\Policies;

use App\Enums\PostApprovalStatus;
use App\Enums\PostModerationStatus;
use App\Models\Post;
use App\Models\User;
use Illuminate\Support\Facades\Gate;

class PostPolicy
{
    public function before(User $user, string $ability): ?bool
    {
        return $user->is_admin ? true : null;
    }

    public function delete(User $user, Post $post): bool
    {
        return $user->id === $post->author_id;
    }

    public function update(User $user, Post $post): bool
    {
        return $user->id === $post->author_id;
    }

    /**
     * A site-admin-banned/deactivated post is invisible to everyone via the
     * API (staff still see it, via before()'s is_admin bypass, and through
     * Filament which doesn't go through this policy at all). Beneath that:
     * a pending/rejected group post is visible only to its author and to
     * that group's admins (moderation) — every Home Feed post (group_id
     * null) and every approved post is visible to anyone, as before.
     */
    public function view(User $user, Post $post): bool
    {
        if ($post->moderation_status !== PostModerationStatus::Visible) {
            return false;
        }

        if ($post->approval_status === PostApprovalStatus::Approved) {
            return true;
        }

        return $user->id === $post->author_id || $this->moderate($user, $post);
    }

    /**
     * The post's group's creator/admin may approve or reject it.
     */
    public function moderate(User $user, Post $post): bool
    {
        return $post->group_id !== null && Gate::forUser($user)->allows('moderate', $post->group);
    }
}
