<?php

namespace App\Policies;

use App\Models\AiConversation;
use App\Models\User;

class AiConversationPolicy
{
    /**
     * A user's AI chat history is private to them — no admin bypass, unlike
     * the marketplace policies, since there's no moderation surface for it.
     */
    public function view(User $user, AiConversation $conversation): bool
    {
        return $user->id === $conversation->user_id;
    }

    public function sendMessage(User $user, AiConversation $conversation): bool
    {
        return $this->view($user, $conversation);
    }
}
