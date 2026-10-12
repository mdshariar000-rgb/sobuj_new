<?php

namespace App\Services;

use App\Enums\EventAttendeeStatus;
use App\Enums\GroupMemberRole;
use App\Enums\GroupVisibility;
use App\Models\Event;
use App\Models\Group;
use App\Models\User;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;

/**
 * Each event's conversation is a hidden private group (groups.event_id), so
 * it gets everything group chat has — photos, replies, reactions, live
 * updates and push. Its members are always the host plus everyone whose
 * RSVP is "going"; nobody else can read it. Hidden from group lists and
 * search (see Group::scopeListed()).
 */
class EventChatService
{
    /** Whether [user] may take part in [event]'s conversation. */
    public function canChat(Event $event, User $user): bool
    {
        return $user->id === (int) $event->host_id
            || $event->attendees()
                ->where('user_id', $user->id)
                ->wherePivot('status', EventAttendeeStatus::Going)
                ->exists();
    }

    /** The event's chat group, created on first use, with members in sync. */
    public function chatFor(Event $event): Group
    {
        $group = $event->chatGroup ?? $this->create($event);

        if ($group->name !== $event->title) {
            $group->forceFill(['name' => $event->title])->save();
        }

        $this->syncMembers($event, $group);

        return $group;
    }

    /**
     * Call after [user]'s RSVP changes: adds them when going, removes them
     * otherwise. Does nothing until the chat has been opened once — chatFor()
     * then syncs everyone.
     */
    public function syncAttendee(Event $event, User $user): void
    {
        $group = $event->chatGroup;
        if ($group === null || $user->id === (int) $event->host_id) {
            return;
        }

        if ($this->canChat($event, $user)) {
            $this->attach($group, $user->id, GroupMemberRole::Member);
        } else {
            $group->members()->detach($user->id);
        }
    }

    private function create(Event $event): Group
    {
        $group = new Group([
            'name' => $event->title,
            'slug' => "event-{$event->id}-chat",
            'visibility' => GroupVisibility::Private,
        ]);
        $group->created_by = $event->host_id;
        $group->event_id = $event->id;

        try {
            $group->save();
        } catch (UniqueConstraintViolationException) {
            // Opened by someone else a moment ago.
            return Group::where('event_id', $event->id)->firstOrFail();
        }

        $event->setRelation('chatGroup', $group);

        return $group;
    }

    private function syncMembers(Event $event, Group $group): void
    {
        $goingIds = $event->attendees()
            ->wherePivot('status', EventAttendeeStatus::Going)
            ->pluck('users.id')
            ->map(fn ($id) => (int) $id);
        $hostId = (int) $event->host_id;

        DB::transaction(function () use ($group, $goingIds, $hostId) {
            $group->members()->detach(
                $group->members()->pluck('users.id')
                    ->map(fn ($id) => (int) $id)
                    ->reject(fn (int $id) => $id === $hostId || $goingIds->contains($id))
                    ->all(),
            );

            $this->attach($group, $hostId, GroupMemberRole::Admin);
            foreach ($goingIds as $id) {
                $this->attach($group, $id, GroupMemberRole::Member);
            }
        });
    }

    private function attach(Group $group, int $userId, GroupMemberRole $role): void
    {
        if ($group->members()->where('user_id', $userId)->exists()) {
            return;
        }

        $group->members()->attach($userId, [
            'role' => $role,
            'joined_at' => now(),
            'last_read_message_id' => (int) $group->messages()->max('id'),
        ]);
    }
}
