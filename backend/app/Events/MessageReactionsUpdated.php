<?php

namespace App\Events;

use App\Models\Message;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Tells everyone viewing a swap-offer thread that a message's reactions changed,
 * with the message's full new reaction summary (see reactionSummary()).
 * ShouldBroadcastNow for the same reason as the message-sent events: there
 * is no queue worker in production.
 */
class MessageReactionsUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public Message $message) {}

    /**
     * @return array<int, Channel>
     */
    public function broadcastOn(): array
    {
        return [new PrivateChannel("swap.{$this->message->swap_offer_id}")];
    }

    public function broadcastAs(): string
    {
        return 'message.reacted';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'message_id' => $this->message->id,
            'reactions' => $this->message->reactionSummary(),
        ];
    }
}
