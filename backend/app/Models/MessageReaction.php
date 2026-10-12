<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * One person's emoji reaction to a Message — at most one per person per
 * message (unique on message_id + user_id).
 */
class MessageReaction extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'message_id',
        'user_id',
        'emoji',
    ];

    /**
     * @return BelongsTo<Message, MessageReaction>
     */
    public function message(): BelongsTo
    {
        return $this->belongsTo(Message::class, 'message_id');
    }

    /**
     * @return BelongsTo<User, MessageReaction>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
