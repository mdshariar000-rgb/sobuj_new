<?php

namespace App\Models;

use App\Models\Concerns\HasMessageImages;
use Database\Factories\GroupMessageFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class GroupMessage extends Model
{
    /** @use HasFactory<GroupMessageFactory> */
    use HasFactory, HasMessageImages;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'group_id',
        'body',
        'image_path',
        'reply_to_id',
    ];

    /**
     * @return BelongsTo<Group, GroupMessage>
     */
    public function group(): BelongsTo
    {
        return $this->belongsTo(Group::class);
    }

    /**
     * Null for a message whose original sender has since deleted their account.
     *
     * @return BelongsTo<User, GroupMessage>
     */
    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    /**
     * The earlier message this one quotes. Null when it isn't a reply, or
     * when the quoted message has since been deleted.
     *
     * @return BelongsTo<GroupMessage, GroupMessage>
     */
    public function replyTo(): BelongsTo
    {
        return $this->belongsTo(GroupMessage::class, 'reply_to_id');
    }

    /**
     * @return HasMany<GroupMessageReaction>
     */
    public function reactions(): HasMany
    {
        return $this->hasMany(GroupMessageReaction::class, 'group_message_id');
    }
}
