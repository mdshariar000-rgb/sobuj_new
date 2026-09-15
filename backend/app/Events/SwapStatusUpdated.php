<?php

namespace App\Events;

use App\Http\Resources\SwapOfferResource;
use App\Models\SwapOffer;
use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

/**
 * Broadcasts whenever a swap offer's status changes, so both participants' clients can
 * update the status badge and offer details live without polling.
 */
class SwapStatusUpdated implements ShouldBroadcastNow
{
    use Dispatchable, InteractsWithSockets, SerializesModels;

    public function __construct(public SwapOffer $swapOffer) {}

    /**
     * @return array<int, Channel>
     */
    public function broadcastOn(): array
    {
        return [new PrivateChannel("swap.{$this->swapOffer->id}")];
    }

    public function broadcastAs(): string
    {
        return 'swap.status-updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'status' => $this->swapOffer->status->value,
            'status_label' => $this->swapOffer->status->label(),
            'offer' => (new SwapOfferResource($this->swapOffer))->resolve(),
        ];
    }
}
