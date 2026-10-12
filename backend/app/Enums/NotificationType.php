<?php

namespace App\Enums;

enum NotificationType: string
{
    case PostLiked = 'post_liked';
    case PostCommented = 'post_commented';
    case CommentReplied = 'comment_replied';
    case SwapMessageReceived = 'swap_message_received';
    case GroupMessageReceived = 'group_message_received';
    case UserFollowed = 'user_followed';
    case ListingReviewed = 'listing_reviewed';
    case SwapOfferReceived = 'swap_offer_received';
    case SwapOfferUpdated = 'swap_offer_updated';

    public function label(): string
    {
        return match ($this) {
            self::PostLiked => 'Post Liked',
            self::PostCommented => 'Post Commented',
            self::CommentReplied => 'Comment Replied',
            self::SwapMessageReceived => 'Swap Message',
            self::GroupMessageReceived => 'Group Message',
            self::UserFollowed => 'New Follower',
            self::ListingReviewed => 'Listing Reviewed',
            self::SwapOfferReceived => 'New Offer',
            self::SwapOfferUpdated => 'Offer Update',
        };
    }
}
