<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One person's emoji reaction to a GroupMessage — at most one per person per
 * message (unique on group_message_id + user_id).
 */
class GroupMessageReaction extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'group_message_id',
        'user_id',
        'emoji',
    ];

    /**
     * @return BelongsTo<GroupMessage, GroupMessageReaction>
     */
    public function message(): BelongsTo
    {
        return $this->belongsTo(GroupMessage::class, 'group_message_id');
    }

    /**
     * @return BelongsTo<User, GroupMessageReaction>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
