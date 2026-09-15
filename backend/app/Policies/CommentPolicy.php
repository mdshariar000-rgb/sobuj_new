<?php

namespace App\Policies;

use App\Models\Comment;
use App\Models\User;

class CommentPolicy
{
    public function before(User $user, string $ability): ?bool
    {
        return $user->is_admin ? true : null;
    }

    public function delete(User $user, Comment $comment): bool
    {
        return $user->id === $comment->author_id;
    }
}
