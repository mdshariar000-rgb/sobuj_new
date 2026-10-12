<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\GroupMemberRole;
use App\Enums\NotificationType;
use App\Events\GroupMessageReactionsUpdated;
use App\Events\GroupMessageSent;
use App\Http\Controllers\Controller;
use App\Http\Requests\GroupMessage\StoreGroupMessageRequest;
use App\Http\Resources\GroupMessageResource;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Services\ImageService;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Collection;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

class GroupMessageController extends Controller
{
    private const PER_PAGE = 50;

    public function index(Group $group, Request $request): AnonymousResourceCollection
    {
        $this->authorize('view', $group);

        $adminIds = $this->adminMemberIds($group);

        // Fetches the most recent page first (like any real chat app opening
        // to the bottom of the conversation, not its very beginning) — a
        // group with more than PER_PAGE messages used to always show page 1
        // of the *oldest* messages here, since the mobile client never
        // passes a page param. Reversed back into chronological order for
        // display.
        $hiddenUserIds = $request->user()->hiddenUserIds();

        $messages = $group->messages()
            ->where(fn ($query) => $query->whereNull('sender_id')->orWhereNotIn('sender_id', $hiddenUserIds))
            ->with([
                'sender',
                'replyTo.sender',
                // Reactions from blocked users are withheld like their messages.
                'reactions' => fn ($query) => $query->whereNotIn('user_id', $hiddenUserIds),
            ])
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();
        $messages->setCollection($messages->getCollection()->reverse()->values());

        $messages->getCollection()->each(function ($message) use ($adminIds, $hiddenUserIds) {
            $message->setAttribute(
                'sender_is_admin',
                $message->sender_id !== null && $adminIds->contains($message->sender_id),
            );

            // A quoted message from someone the viewer has blocked (or been
            // blocked by) is withheld, same as that person's own messages —
            // the reply then shows the quote as unavailable.
            if ($message->replyTo?->sender_id !== null && in_array($message->replyTo->sender_id, $hiddenUserIds, true)) {
                $message->setRelation('replyTo', null);
            }
        });

        // Opening the chat is what "reads" it — same trigger as
        // MessageController::index() for the 1:1 swap-offer thread, just
        // tracked as a per-user message-id watermark on group_members
        // instead of a per-message read_at (a message here has many
        // readers, not two — see GroupController::index()'s unread_count
        // subquery for why it's an id rather than a timestamp). Only ever
        // advanced, never regressed: if this ever grows an infinite-scroll-
        // up feature, fetching an older page (lower ids) must not un-read
        // newer messages the member already saw on a previous, more recent
        // page.
        $maxReturnedId = $messages->getCollection()->max('id');
        $currentWatermark = $group->members()
            ->where('user_id', $request->user()->id)
            ->value('group_members.last_read_message_id');
        if ($maxReturnedId !== null && $maxReturnedId > $currentWatermark) {
            $group->members()->updateExistingPivot($request->user()->id, [
                'last_read_message_id' => $maxReturnedId,
            ]);
        }

        return GroupMessageResource::collection($messages);
    }

    public function store(StoreGroupMessageRequest $request, Group $group, ImageService $imageService, NotificationService $notificationService): JsonResponse
    {
        $this->authorize('sendMessage', $group);

        $message = $group->messages()->make([
            'body' => $request->validated('body'),
            'reply_to_id' => $request->validated('reply_to_id'),
        ]);
        $message->setImagePaths(array_map(
            fn (UploadedFile $file) => $imageService->store($file, "groups/{$group->id}/messages"),
            $request->uploadedImages(),
        ));
        $message->sender_id = $request->user()->id;
        $message->save();

        $message->load(['sender', 'replyTo.sender', 'reactions']);
        $message->setAttribute(
            'sender_is_admin',
            $this->adminMemberIds($group)->contains($request->user()->id),
        );

        // toOthers(): the sender's own client already has this message from the
        // HTTP response it's about to receive — see MessageController::store()
        // for the identical rationale.
        broadcast(new GroupMessageSent($message))->toOthers();

        $recipients = $group->members()->where('user_id', '!=', $request->user()->id)->get();
        $notificationService->notifyMany(
            $recipients,
            $request->user(),
            NotificationType::GroupMessageReceived,
            "{$request->user()->name} in {$group->name}",
            $message->body !== null ? Str::limit($message->body, 100) : $message->photoPreviewText(),
            ['group_id' => $group->id],
        );

        return (new GroupMessageResource($message))->response()->setStatusCode(201);
    }

    /**
     * @return Collection<int, int>
     */
    private function adminMemberIds(Group $group): Collection
    {
        return $group->members()
            ->wherePivot('role', GroupMemberRole::Admin)
            ->pluck('users.id');
    }

    /**
     * PUT /groups/{group}/messages/{groupMessage}/reaction — sets the
     * caller's reaction, replacing any earlier one on the same message.
     */
    public function react(Request $request, Group $group, GroupMessage $groupMessage): JsonResponse
    {
        $this->authorizeReaction($request, $group, $groupMessage);
        $data = $request->validate([
            'emoji' => ['required', 'string', Rule::in(GroupMessage::REACTION_EMOJIS)],
        ]);

        $groupMessage->reactions()->updateOrCreate(
            ['user_id' => $request->user()->id],
            ['emoji' => $data['emoji']],
        );

        return $this->reactionsResponse($groupMessage);
    }

    /**
     * DELETE /groups/{group}/messages/{groupMessage}/reaction — removes the
     * caller's reaction, if any.
     */
    public function unreact(Request $request, Group $group, GroupMessage $groupMessage): JsonResponse
    {
        $this->authorizeReaction($request, $group, $groupMessage);

        $groupMessage->reactions()->where('user_id', $request->user()->id)->delete();

        return $this->reactionsResponse($groupMessage);
    }

    private function authorizeReaction(Request $request, Group $group, GroupMessage $groupMessage): void
    {
        $this->authorize('sendMessage', $group);
        abort_unless((int) $groupMessage->group_id === $group->id, 404);
        // A blocked user's messages are hidden from the caller, so they can't
        // be reacted to either.
        abort_if(
            $groupMessage->sender_id !== null && in_array($groupMessage->sender_id, $request->user()->hiddenUserIds(), true),
            404,
        );
    }

    private function reactionsResponse(GroupMessage $groupMessage): JsonResponse
    {
        $groupMessage->load('reactions');

        // toOthers(): the reacting client already has the new state from this
        // response — see store() for the same reasoning.
        broadcast(new GroupMessageReactionsUpdated($groupMessage))->toOthers();

        return response()->json(['data' => [
            'message_id' => $groupMessage->id,
            'reactions' => $groupMessage->reactionSummary(),
        ]]);
    }
}
