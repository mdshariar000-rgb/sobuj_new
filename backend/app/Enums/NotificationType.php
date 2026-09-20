<?php

namespace App\Enums;

enum NotificationType: string
{
    case PostLiked = 'post_liked';
    case PostCommented = 'post_commented';
    case CommentReplied = 'comment_replied';
    case SwapMessageReceived = 'swap_message_received';
    case GroupMessageReceived = 'group_message_received';

    public function label(): string
    {
        return match ($this) {
            self::PostLiked => 'Post Liked',
            self::PostCommented => 'Post Commented',
            self::CommentReplied => 'Comment Replied',
            self::SwapMessageReceived => 'Swap Message',
            self::GroupMessageReceived => 'Group Message',
        };
    }
}
