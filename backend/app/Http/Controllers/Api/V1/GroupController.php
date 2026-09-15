<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\GroupJoinRequestStatus;
use App\Enums\GroupMemberRole;
use App\Enums\GroupStatus;
use App\Enums\GroupVisibility;
use App\Enums\PostApprovalStatus;
use App\Http\Controllers\Controller;
use App\Http\Requests\Group\StoreGroupRequest;
use App\Http\Requests\Group\UpdateGroupRequest;
use App\Http\Resources\GroupMemberResource;
use App\Http\Resources\GroupResource;
use App\Models\Group;
use App\Services\ImageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class GroupController extends Controller
{
    private const PER_PAGE = 20;

    public function index(Request $request): AnonymousResourceCollection
    {
        $groups = Group::query()
            ->where('status', GroupStatus::Active)
            ->when($request->filled('category'), fn ($query) => $query->where('category', $request->string('category')))
            ->when($request->filled('search'), fn ($query) => $query->where('name', 'like', '%'.$request->string('search').'%'))
            ->withCount([
                'members',
                // Pending posts don't count toward a group's visible activity.
                'posts as posts_today_count' => fn ($query) => $query
                    ->whereDate('created_at', today())
                    ->where('approval_status', PostApprovalStatus::Approved),
                'joinRequests as pending_join_requests_count' => fn ($query) => $query
                    ->where('status', GroupJoinRequestStatus::Pending),
            ])
            // A cheap correlated-subquery boolean rather than eager-loading every
            // group's full member list just to test one user's membership — see
            // GroupResource::is_member, which reads this same alias.
            ->withExists(['members as is_member' => fn ($query) => $query->where('user_id', $request->user()->id)])
            // Real per-user "have I already asked to join this private
            // group" flag — see GroupResource::join_request_pending.
            ->withExists(['joinRequests as join_request_pending' => fn ($query) => $query
                ->where('user_id', $request->user()->id)
                ->where('status', GroupJoinRequestStatus::Pending),
            ])
            // Real unread count for the Groups list's chat preview — group
            // chat has no per-message read state (unlike the 1:1 swap-offer
            // thread's messages.read_at), so "read" is a per-user-per-group
            // message-id watermark on group_members instead (a timestamp
            // watermark would tie whenever a join and a send land in the
            // same second at this app's timestamp precision; an
            // auto-increment id can't). Always set to a real value — see
            // GroupController::join()/store() and GroupMessageController::
            // index() — so this never compares against an unset threshold
            // for a real member. Zero for a group this user hasn't joined,
            // since the inner subquery then has no matching group_members
            // row to compare against.
            ->addSelect(['unread_count' => DB::table('group_messages')
                ->selectRaw('COUNT(*)')
                ->whereColumn('group_messages.group_id', 'groups.id')
                ->where('group_messages.sender_id', '!=', $request->user()->id)
                ->where('group_messages.id', '>', function ($query) use ($request) {
                    $query->select('last_read_message_id')
                        ->from('group_members')
                        ->whereColumn('group_members.group_id', 'groups.id')
                        ->where('group_members.user_id', $request->user()->id);
                }),
            ])
            ->with(['creator', 'latestMessage.sender'])
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return GroupResource::collection($groups);
    }

    public function store(StoreGroupRequest $request, ImageService $imageService): JsonResponse
    {
        $data = $request->validated();
        $user = $request->user();

        $group = DB::transaction(function () use ($data, $user, $request, $imageService) {
            $group = new Group([
                'name' => $data['name'],
                'slug' => $data['slug'],
                'description' => $data['description'] ?? null,
                'category' => $data['category'] ?? null,
                'visibility' => $data['visibility'] ?? GroupVisibility::Public->value,
            ]);
            $group->created_by = $user->id;

            if ($request->hasFile('cover_image')) {
                $group->cover_image_path = $imageService->store($request->file('cover_image'), 'groups');
            }

            if ($request->hasFile('avatar')) {
                $group->avatar_path = $imageService->store($request->file('avatar'), 'groups');
            }

            $group->save();

            // The creator is automatically an admin member of their own group.
            // No messages exist yet on a brand-new group, so 0 is correct.
            $group->members()->attach($user->id, [
                'role' => GroupMemberRole::Admin,
                'joined_at' => now(),
                'last_read_message_id' => 0,
            ]);

            return $group;
        });

        return (new GroupResource($group->fresh(['creator', 'members'])->loadCount(['members', 'posts'])))
            ->response()
            ->setStatusCode(201);
    }

    public function show(Request $request, Group $group): GroupResource
    {
        abort_if($group->status !== GroupStatus::Active, 403, 'This group is no longer available.');

        $group->loadCount([
            'members',
            'posts' => fn ($query) => $query->where('approval_status', PostApprovalStatus::Approved),
            'posts as posts_today_count' => fn ($query) => $query
                ->whereDate('created_at', today())
                ->where('approval_status', PostApprovalStatus::Approved),
            'joinRequests as pending_join_requests_count' => fn ($query) => $query
                ->where('status', GroupJoinRequestStatus::Pending),
        ])->loadMissing(['creator', 'members', 'pinnedBy']);

        $group->setAttribute(
            'join_request_pending',
            $group->joinRequests()
                ->where('user_id', $request->user()->id)
                ->where('status', GroupJoinRequestStatus::Pending)
                ->exists(),
        );

        return new GroupResource($group);
    }

    public function update(UpdateGroupRequest $request, Group $group, ImageService $imageService): GroupResource
    {
        $this->authorize('update', $group);

        $data = $request->validated();

        DB::transaction(function () use ($data, $group, $request, $imageService) {
            $group->fill(array_intersect_key($data, array_flip(['name', 'slug', 'description', 'category', 'visibility'])));

            if ($request->hasFile('cover_image')) {
                $group->cover_image_path = $imageService->store($request->file('cover_image'), 'groups');
            }

            if ($request->hasFile('avatar')) {
                $group->avatar_path = $imageService->store($request->file('avatar'), 'groups');
            }

            // Not mass-assigned via fill() above — pinning carries side effects
            // (who/when) that a plain fillable field can't express, and this
            // endpoint is already admin/creator-gated by the authorize() call.
            if (array_key_exists('pinned_message', $data)) {
                $pinnedMessage = $data['pinned_message'] !== null ? trim((string) $data['pinned_message']) : null;
                if ($pinnedMessage === '' || $pinnedMessage === null) {
                    $group->pinned_message = null;
                    $group->pinned_by = null;
                    $group->pinned_at = null;
                } else {
                    $group->pinned_message = $pinnedMessage;
                    $group->pinned_by = $request->user()->id;
                    $group->pinned_at = now();
                }
            }

            $group->save();

            // Switching to public removes the barrier every pending request
            // was waiting on — leaving them stuck in limbo would be a bug,
            // not a feature, so they become real members immediately.
            if ($group->wasChanged('visibility') && $group->visibility === GroupVisibility::Public) {
                $group->joinRequests()
                    ->where('status', GroupJoinRequestStatus::Pending)
                    ->get()
                    ->each(function ($joinRequest) use ($group) {
                        $group->members()->attach($joinRequest->user_id, [
                            'role' => GroupMemberRole::Member,
                            'joined_at' => now(),
                            'last_read_message_id' => $group->messages()->max('id') ?? 0,
                        ]);
                        $joinRequest->delete();
                    });
            }
        });

        return new GroupResource($group->fresh(['creator', 'members', 'pinnedBy'])->loadCount(['members', 'posts']));
    }

    public function destroy(Group $group): JsonResponse
    {
        $this->authorize('delete', $group);

        // Hard delete: cascades to the group's posts, memberships, and events at the
        // DB level (see 2025_02_04_* migrations) — unlike Listing there's no cross-user
        // negotiation history tied to a group that would need to survive its removal.
        $group->delete();

        return response()->json(['message' => 'Group deleted.']);
    }

    /**
     * Joins a public group instantly. A private group instead files a real
     * join request (202, no group payload — there's no membership yet) for
     * the group's admin to approve/reject — see GroupJoinRequestController.
     */
    public function join(Request $request, Group $group): GroupResource|JsonResponse
    {
        abort_if($group->status !== GroupStatus::Active, 403, 'This group is no longer available.');

        $user = $request->user();

        if ($group->members()->where('user_id', $user->id)->exists()) {
            throw ValidationException::withMessages([
                'group' => ['You are already a member of this group.'],
            ]);
        }

        if ($group->visibility === GroupVisibility::Private) {
            $existing = $group->joinRequests()->where('user_id', $user->id)->first();

            if ($existing?->status === GroupJoinRequestStatus::Pending) {
                throw ValidationException::withMessages([
                    'group' => ['Your request to join is already pending approval.'],
                ]);
            }

            // updateOrCreate rather than a plain insert so a previously
            // rejected request can be re-requested without tripping the
            // (group_id, user_id) unique constraint.
            $group->joinRequests()->updateOrCreate(
                ['user_id' => $user->id],
                [
                    'status' => GroupJoinRequestStatus::Pending,
                    'requested_at' => now(),
                    'decided_at' => null,
                    'decided_by' => null,
                ],
            );

            return response()->json([
                'message' => 'Your request to join has been sent to the group admin.',
            ], 202);
        }

        // Starts caught up on everything sent before joining — only messages
        // from here on should ever count as unread for this member.
        $group->members()->attach($user->id, [
            'role' => GroupMemberRole::Member,
            'joined_at' => now(),
            'last_read_message_id' => $group->messages()->max('id') ?? 0,
        ]);

        return new GroupResource($group->fresh(['creator', 'members'])->loadCount(['members', 'posts']));
    }

    /**
     * Lets a user withdraw their own still-pending request to join a
     * private group, so they aren't stuck waiting forever if they change
     * their mind.
     */
    public function cancelJoinRequest(Request $request, Group $group): JsonResponse
    {
        $joinRequest = $group->joinRequests()
            ->where('user_id', $request->user()->id)
            ->where('status', GroupJoinRequestStatus::Pending)
            ->first();

        abort_if($joinRequest === null, 404);

        $joinRequest->delete();

        return response()->json(['message' => 'Join request canceled.']);
    }

    public function leave(Request $request, Group $group): JsonResponse
    {
        $user = $request->user();

        if ($user->id === $group->created_by) {
            throw ValidationException::withMessages([
                'group' => ['The group creator cannot leave their own group.'],
            ]);
        }

        $group->members()->detach($user->id);

        return response()->json(['message' => 'Left group.']);
    }

    /**
     * A group's real member roster — admins first, then by join date. Used
     * by the mobile app's "Members" tab on the group detail screen.
     */
    public function members(Group $group): AnonymousResourceCollection
    {
        $members = $group->members()
            ->orderByPivot('role')
            ->orderByPivot('joined_at')
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return GroupMemberResource::collection($members);
    }
}
