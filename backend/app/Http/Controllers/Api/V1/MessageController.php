<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\MessageType;
use App\Events\MessageSent;
use App\Http\Controllers\Controller;
use App\Http\Requests\Message\StoreMessageRequest;
use App\Http\Resources\MessageResource;
use App\Models\SwapOffer;
use App\Services\ImageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class MessageController extends Controller
{
    private const PER_PAGE = 50;

    public function index(Request $request, SwapOffer $swapOffer): AnonymousResourceCollection
    {
        $this->authorize('view', $swapOffer);

        // Fetches the most recent page first (like any real chat app opening
        // to the bottom of the conversation, not its very beginning) — a
        // thread with more than PER_PAGE messages used to always show page
        // 1 of the *oldest* messages here, since the mobile client never
        // passes a page param. Reversed back into chronological order for
        // display; a later page (older messages) would need reversing the
        // same way if this ever grows an infinite-scroll-up feature.
        $messages = $swapOffer->messages()
            ->with('sender')
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();
        $messages->setCollection($messages->getCollection()->reverse()->values());

        // Opening the thread is what "reads" it — mark every message not sent
        // by this user as read, same as any chat app's read-receipt trigger.
        $swapOffer->messages()
            ->whereNull('read_at')
            ->where(fn ($query) => $query->whereNull('sender_id')->orWhere('sender_id', '!=', $request->user()->id))
            ->update(['read_at' => now()]);

        return MessageResource::collection($messages);
    }

    public function store(StoreMessageRequest $request, SwapOffer $swapOffer, ImageService $imageService): JsonResponse
    {
        $this->authorize('sendMessage', $swapOffer);

        $imagePath = $request->hasFile('image')
            ? $imageService->store($request->file('image'), "swap-offers/{$swapOffer->id}")
            : null;

        $message = $swapOffer->messages()->create([
            'sender_id' => $request->user()->id,
            'message_type' => MessageType::Text,
            'body' => $request->validated('body'),
            'image_path' => $imagePath,
        ]);

        $message->load('sender');

        // toOthers(): the sender's own client already has this message from the HTTP
        // response it's about to receive, so re-delivering it over the socket would
        // just duplicate it there. Everyone else on the thread gets it live.
        broadcast(new MessageSent($message))->toOthers();

        return (new MessageResource($message))->response()->setStatusCode(201);
    }
}
