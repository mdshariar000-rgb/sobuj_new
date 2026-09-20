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

    /**
     * The comment's own author, or the author of the post it's on (a post
     * owner can moderate comments left on their own post, same as most
     * social apps) — either may delete it.
     */
    public function delete(User $user, Comment $comment): bool
    {
        return $user->id === $comment->author_id || $user->id === $comment->post->author_id;
    }
}
