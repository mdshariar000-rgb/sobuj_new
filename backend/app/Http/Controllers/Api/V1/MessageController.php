<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\MessageType;
use App\Enums\NotificationType;
use App\Events\MessageReactionsUpdated;
use App\Events\MessageSent;
use App\Http\Controllers\Controller;
use App\Http\Requests\Message\StoreMessageRequest;
use App\Http\Resources\MessageResource;
use App\Models\Message;
use App\Models\SwapOffer;
use App\Models\User;
use App\Services\ImageService;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

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
            ->with(['sender', 'replyTo.sender', 'reactions'])
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

    public function store(StoreMessageRequest $request, SwapOffer $swapOffer, ImageService $imageService, NotificationService $notificationService): JsonResponse
    {
        $this->authorize('sendMessage', $swapOffer);

        $otherPartyId = $this->otherPartyId($request, $swapOffer);
        abort_if($request->user()->hasBlockRelationWith($otherPartyId), 403, "You can't message this user.");

        $message = $swapOffer->messages()->make([
            'sender_id' => $request->user()->id,
            'message_type' => MessageType::Text,
            'body' => $request->validated('body'),
            'reply_to_id' => $request->validated('reply_to_id'),
        ]);
        $message->setImagePaths(array_map(
            fn (UploadedFile $file) => $imageService->store($file, "swap-offers/{$swapOffer->id}"),
            $request->uploadedImages(),
        ));
        $message->save();

        $message->load(['sender', 'replyTo.sender', 'reactions']);

        // toOthers(): the sender's own client already has this message from the HTTP
        // response it's about to receive, so re-delivering it over the socket would
        // just duplicate it there. Everyone else on the thread gets it live.
        broadcast(new MessageSent($message))->toOthers();

        $notificationService->notify(
            User::findOrFail($otherPartyId),
            $request->user(),
            NotificationType::SwapMessageReceived,
            "{$request->user()->name} sent you a message",
            $message->body !== null ? Str::limit($message->body, 100) : $message->photoPreviewText(),
            ['swap_offer_id' => $swapOffer->id],
        );

        return (new MessageResource($message))->response()->setStatusCode(201);
    }

    /**
     * PUT /swap-offers/{swapOffer}/messages/{message}/reaction — sets the
     * caller's reaction, replacing any earlier one on the same message.
     */
    public function react(Request $request, SwapOffer $swapOffer, Message $message): JsonResponse
    {
        $this->authorizeReaction($request, $swapOffer, $message);
        $data = $request->validate([
            'emoji' => ['required', 'string', Rule::in(Message::REACTION_EMOJIS)],
        ]);

        $message->reactions()->updateOrCreate(
            ['user_id' => $request->user()->id],
            ['emoji' => $data['emoji']],
        );

        return $this->reactionsResponse($message);
    }

    /**
     * DELETE /swap-offers/{swapOffer}/messages/{message}/reaction — removes
     * the caller's reaction, if any.
     */
    public function unreact(Request $request, SwapOffer $swapOffer, Message $message): JsonResponse
    {
        $this->authorizeReaction($request, $swapOffer, $message);

        $message->reactions()->where('user_id', $request->user()->id)->delete();

        return $this->reactionsResponse($message);
    }

    private function authorizeReaction(Request $request, SwapOffer $swapOffer, Message $message): void
    {
        $this->authorize('view', $swapOffer);
        abort_unless((int) $message->swap_offer_id === $swapOffer->id, 404);
        abort_if(
            $request->user()->hasBlockRelationWith($this->otherPartyId($request, $swapOffer)),
            403,
            "You can't react to this user's messages.",
        );
    }

    private function reactionsResponse(Message $message): JsonResponse
    {
        $message->load('reactions');

        // toOthers(): the reacting client already has the new state from this
        // response — see store() for the same reasoning.
        broadcast(new MessageReactionsUpdated($message))->toOthers();

        return response()->json(['data' => [
            'message_id' => $message->id,
            'reactions' => $message->reactionSummary(),
        ]]);
    }

    private function otherPartyId(Request $request, SwapOffer $swapOffer): int
    {
        $swapOffer->loadMissing('listing');

        return $swapOffer->requester_id === $request->user()->id
            ? $swapOffer->listing->user_id
            : $swapOffer->requester_id;
    }
}
