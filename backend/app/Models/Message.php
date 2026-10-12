<?php

namespace App\Models;

use App\Enums\MessageType;
use App\Models\Concerns\HasMessageImages;
use Database\Factories\MessageFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Message extends Model
{
    /** @use HasFactory<MessageFactory> */
    use HasFactory, HasMessageImages;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'swap_offer_id',
        'sender_id',
        'message_type',
        'body',
        'image_path',
        'reply_to_id',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'message_type' => MessageType::class,
            'read_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<SwapOffer, Message>
     */
    public function swapOffer(): BelongsTo
    {
        return $this->belongsTo(SwapOffer::class);
    }

    /**
     * Null for system-generated events with no acting user.
     *
     * @return BelongsTo<User, Message>
     */
    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    /**
     * The earlier message this one quotes. Null when it isn't a reply, or
     * when the quoted message has since been deleted.
     *
     * @return BelongsTo<Message, Message>
     */
    public function replyTo(): BelongsTo
    {
        return $this->belongsTo(Message::class, 'reply_to_id');
    }

    /**
     * @return HasMany<MessageReaction>
     */
    public function reactions(): HasMany
    {
        return $this->hasMany(MessageReaction::class, 'message_id');
    }
}
