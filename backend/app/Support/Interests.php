<?php

namespace App\Support;

/**
 * The interests a user can pick when signing up (stored in
 * users.growing_interests). Each one has its own group — see
 * AutoGroupService.
 */
final class Interests
{
    public const ALL = [
        'Learning to garden',
        'Buyer',
        'Seller',
        'Garden Project',
        'Community Engagement',
        'Sustainability',
        'Community Gardening',
        'Wildlife & Biodiversity',
        'Research & Education',
    ];
}
