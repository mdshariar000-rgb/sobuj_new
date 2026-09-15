<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\GroupJoinRequestStatus;
use App\Enums\GroupMemberRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\GroupJoinRequest\UpdateGroupJoinRequestRequest;
use App\Http\Resources\GroupJoinRequestResource;
use App\Models\Group;
use App\Models\GroupJoinRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class GroupJoinRequestController extends Controller
{
    private const PER_PAGE = 20;

    /**
     * The group admin/creator's real pending join requests, oldest first —
     * a short admin-only moderation queue, not user-generated content.
     */
    public function index(Group $group): AnonymousResourceCollection
    {
        $this->authorize('moderate', $group);

        $requests = $group->joinRequests()
            ->where('status', GroupJoinRequestStatus::Pending)
            ->with('user')
            ->oldest('requested_at')
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return GroupJoinRequestResource::collection($requests);
    }

    /**
     * Approving deletes the request and creates a real group_members row
     * (no "approved" status is ever stored — see the group_join_requests
     * migration). Rejecting keeps the row so the requester's earlier
     * attempt is real history, and so GroupController::join() can tell
     * a fresh request apart from a re-request.
     */
    public function update(UpdateGroupJoinRequestRequest $request, Group $group, GroupJoinRequest $joinRequest): JsonResponse
    {
        $this->authorize('moderate', $group);
        abort_if($joinRequest->group_id !== $group->id, 404);

        if ($request->validated('decision') === 'approve') {
            DB::transaction(function () use ($group, $joinRequest) {
                $group->members()->attach($joinRequest->user_id, [
                    'role' => GroupMemberRole::Member,
                    'joined_at' => now(),
                    'last_read_message_id' => $group->messages()->max('id') ?? 0,
                ]);
                $joinRequest->delete();
            });

            return response()->json(['message' => 'Join request approved.']);
        }

        $joinRequest->update([
            'status' => GroupJoinRequestStatus::Rejected,
            'decided_at' => now(),
            'decided_by' => $request->user()->id,
        ]);

        return response()->json(['message' => 'Join request rejected.']);
    }
}
