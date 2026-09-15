<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\GroupMemberRole;
use App\Events\GroupMessageSent;
use App\Http\Controllers\Controller;
use App\Http\Requests\GroupMessage\StoreGroupMessageRequest;
use App\Http\Resources\GroupMessageResource;
use App\Models\Group;
use App\Services\ImageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Collection;

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
        $messages = $group->messages()
            ->with('sender')
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();
        $messages->setCollection($messages->getCollection()->reverse()->values());

        $messages->getCollection()->each(
            fn ($message) => $message->setAttribute(
                'sender_is_admin',
                $message->sender_id !== null && $adminIds->contains($message->sender_id),
            ),
        );

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

    public function store(StoreGroupMessageRequest $request, Group $group, ImageService $imageService): JsonResponse
    {
        $this->authorize('sendMessage', $group);

        $imagePath = $request->hasFile('image')
            ? $imageService->store($request->file('image'), "groups/{$group->id}/messages")
            : null;

        $message = $group->messages()->create([
            'body' => $request->validated('body'),
            'image_path' => $imagePath,
        ]);
        $message->sender_id = $request->user()->id;
        $message->save();

        $message->load('sender');
        $message->setAttribute(
            'sender_is_admin',
            $this->adminMemberIds($group)->contains($request->user()->id),
        );

        // toOthers(): the sender's own client already has this message from the
        // HTTP response it's about to receive — see MessageController::store()
        // for the identical rationale.
        broadcast(new GroupMessageSent($message))->toOthers();

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
}
