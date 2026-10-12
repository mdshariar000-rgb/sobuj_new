<?php

namespace App\Enums;

use App\Models\Comment;
use App\Models\Event;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\Listing;
use App\Models\Message;
use App\Models\Post;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;

enum ReportTargetType: string
{
    case Post = 'post';
    case Comment = 'comment';
    case Listing = 'listing';
    case Event = 'event';
    case Group = 'group';
    case User = 'user';
    case GroupMessage = 'group_message';
    case Message = 'message';

    /**
     * @return class-string<Model>
     */
    public function modelClass(): string
    {
        return match ($this) {
            self::Post => Post::class,
            self::Comment => Comment::class,
            self::Listing => Listing::class,
            self::Event => Event::class,
            self::Group => Group::class,
            self::User => User::class,
            self::GroupMessage => GroupMessage::class,
            self::Message => Message::class,
        };
    }

    /**
     * The column on the reported row that points at the user who authored/owns it —
     * used to stop someone reporting their own content and to attribute a report.
     */
    public function ownerColumn(): string
    {
        return match ($this) {
            self::Post, self::Comment => 'author_id',
            self::Listing => 'user_id',
            self::Event => 'host_id',
            self::Group => 'created_by',
            self::User => 'id',
            self::GroupMessage, self::Message => 'sender_id',
        };
    }

    public function label(): string
    {
        return match ($this) {
            self::Post => 'Post',
            self::Comment => 'Comment',
            self::Listing => 'Listing',
            self::Event => 'Event',
            self::Group => 'Group',
            self::User => 'User',
            self::GroupMessage => 'Group message',
            self::Message => 'Swap message',
        };
    }
}
