<?php

namespace App\Http\Resources;

use App\Models\Group;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Storage;

/**
 * @mixin Group
 */
class GroupResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'slug' => $this->slug,
            'description' => $this->description,
            'category' => $this->category,
            'visibility' => $this->visibility->value,
            'verified' => $this->verified_at !== null,
            'cover_image_url' => $this->cover_image_path !== null
                ? Storage::disk('public')->url($this->cover_image_path)
                : null,
            'avatar_url' => $this->avatar_path !== null
                ? Storage::disk('public')->url($this->avatar_path)
                : null,
            'members_count' => $this->whenCounted('members'),
            // Real total discussion-post count — the "All Posts" tab label.
            'posts_count' => $this->whenCounted('posts'),
            // Real count of this group's discussion posts created today — see
            // GroupController::index()/show(), which alias it via withCount()/
            // loadCount() the same way UserResource does for active_listings_count.
            'posts_today_count' => $this->when(
                array_key_exists('posts_today_count', $this->resource->getAttributes()),
                fn () => (int) $this->posts_today_count,
            ),
            // Only on GET /groups/suggested: members from the viewer's city,
            // and whether the group is for that city (named after it or has
            // members there) — see GroupController::suggested().
            'local_members_count' => $this->when(
                array_key_exists('local_members_count', $this->resource->getAttributes()),
                fn () => (int) $this->local_members_count,
            ),
            // Only on GET /groups: when anyone last posted or chatted there.
            'last_activity_at' => $this->when(
                array_key_exists('last_activity_at', $this->resource->getAttributes()),
                fn () => $this->last_activity_at !== null
                    ? Carbon::parse($this->last_activity_at)->toIso8601String()
                    : null,
            ),
            'is_local' => $this->when(
                array_key_exists('named_after_city', $this->resource->getAttributes()),
                fn () => (bool) $this->named_after_city || (int) $this->local_members_count > 0,
            ),
            // Null for groups the app made earlier at sign-up (see AutoGroupService).
            'creator' => $this->whenLoaded(
                'creator',
                fn () => $this->creator !== null ? new UserResource($this->creator) : null,
            ),
            'auto_type' => $this->auto_type,
            // Set on an event's chat group — see EventChatService.
            'event_id' => $this->event_id,
            // Two ways this gets populated depending on the endpoint: index() uses
            // withExists() (a cheap correlated-subquery bool, aliased onto this same
            // `is_member` attribute — see GroupController::index()); show()/store()/
            // join() eager-load the full `members` relation instead and this falls
            // back to checking it directly.
            'is_member' => $this->when(
                $request->user() !== null && ($this->relationLoaded('members') || array_key_exists('is_member', $this->resource->getAttributes())),
                fn () => $this->relationLoaded('members')
                    ? $this->members->contains('id', $request->user()->id)
                    : (bool) $this->resource->getAttributes()['is_member'],
            ),
            // The current user's real group_members.role pivot value — only
            // derivable where the full `members` relation is loaded (show()/
            // store()/join()/leave()), used by the app to gate admin-only UI
            // (e.g. pinning a chat message).
            'my_role' => $this->when(
                $request->user() !== null && $this->relationLoaded('members'),
                function () use ($request) {
                    $member = $this->members->firstWhere('id', $request->user()->id);

                    return $member?->pivot->role->value;
                },
            ),
            // True only when *this* user has a real pending request — see
            // GroupController::index()/show()'s join_request_pending
            // correlated select, same dual-purpose convention as is_member.
            'join_request_pending' => $this->when(
                array_key_exists('join_request_pending', $this->resource->getAttributes()),
                fn () => (bool) $this->resource->getAttributes()['join_request_pending'],
            ),
            // Only meaningful to this group's admin — the count of requests
            // awaiting their decision, for a badge on the Groups list/detail
            // header. Always present (like unread_count), zero otherwise.
            'pending_join_requests_count' => $this->when(
                array_key_exists('pending_join_requests_count', $this->resource->getAttributes()),
                fn () => (int) $this->resource->getAttributes()['pending_join_requests_count'],
            ),
            'pinned_message' => $this->pinned_message,
            'pinned_by' => new UserResource($this->whenLoaded('pinnedBy')),
            'pinned_at' => $this->pinned_at?->toIso8601String(),
            // Real unread count for a joined group's chat preview — see
            // GroupController::index()'s correlated-subquery select. Zero
            // (not omitted) for a group this user hasn't joined.
            'unread_count' => $this->when(
                array_key_exists('unread_count', $this->resource->getAttributes()),
                fn () => (int) $this->unread_count,
            ),
            // The group chat's real most-recent message, for the Groups
            // list's conversation-preview — mirrors SwapOfferResource's
            // last_message, just without an is_system_event flag (group
            // chat has no system-event messages).
            'last_message' => $this->whenLoaded(
                'latestMessage',
                fn () => $this->latestMessage === null ? null : [
                    'body' => $this->latestMessage->body,
                    'has_image' => $this->latestMessage->image_path !== null,
                    'sender_id' => $this->latestMessage->sender_id,
                    'sender_name' => $this->latestMessage->sender?->name,
                    'created_at' => $this->latestMessage->created_at?->toIso8601String(),
                ],
            ),
            'created_at' => $this->created_at?->toIso8601String(),
            'updated_at' => $this->updated_at?->toIso8601String(),
        ];
    }
}
