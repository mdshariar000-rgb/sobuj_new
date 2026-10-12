<?php

namespace App\Policies;

use App\Models\ListingReview;
use App\Models\User;

class ListingReviewPolicy
{
    public function before(User $user, string $ability): ?bool
    {
        return $user->is_admin ? true : null;
    }

    /**
     * The review's own author, or the listing's owner (who can moderate
     * reviews left on their own listing, same as CommentPolicy letting a
     * post's author moderate comments left on it) — either may delete it.
     */
    public function delete(User $user, ListingReview $review): bool
    {
        return $user->id === $review->reviewer_id || $user->id === $review->listing->user_id;
    }
}
