<?php

namespace Tests\Feature\Api;

use App\Enums\EventStatus;
use App\Models\Event;
use App\Models\Group;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class EventChatTest extends TestCase
{
    use RefreshDatabase;

    private function rsvp(User $user, Event $event, string $status): void
    {
        Sanctum::actingAs($user);
        $this->postJson("/api/v1/events/{$event->id}/rsvp", ['status' => $status])->assertOk();
    }

    private function openChat(User $user, Event $event): TestResponse
    {
        Sanctum::actingAs($user);

        return $this->getJson("/api/v1/events/{$event->id}/chat");
    }

    public function test_the_host_and_going_attendees_share_one_chat(): void
    {
        $event = Event::factory()->create();
        $going = User::factory()->create();
        $this->rsvp($going, $event, 'going');

        $groupId = $this->openChat($event->host, $event)
            ->assertOk()
            ->assertJsonPath('data.event_id', $event->id)
            ->assertJsonPath('data.name', $event->title)
            ->json('data.id');
        $this->openChat($going, $event)->assertOk()->assertJsonPath('data.id', $groupId);

        $this->postJson("/api/v1/groups/{$groupId}/messages", ['body' => 'See you there!'])->assertCreated();

        Sanctum::actingAs($event->host);
        $this->getJson("/api/v1/groups/{$groupId}/messages")
            ->assertOk()
            ->assertJsonPath('data.0.body', 'See you there!');
    }

    public function test_interested_attendees_and_strangers_cannot_chat(): void
    {
        $event = Event::factory()->create();
        $interested = User::factory()->create();
        $this->rsvp($interested, $event, 'interested');
        $groupId = $this->openChat($event->host, $event)->json('data.id');

        $this->openChat($interested, $event)->assertForbidden();
        $this->getJson("/api/v1/groups/{$groupId}/messages")->assertForbidden();

        $this->openChat(User::factory()->create(), $event)->assertForbidden();
        $this->postJson("/api/v1/groups/{$groupId}/join")->assertForbidden();
    }

    public function test_leaving_going_removes_you_from_the_chat(): void
    {
        $event = Event::factory()->create();
        $user = User::factory()->create();
        $this->rsvp($user, $event, 'going');
        $groupId = $this->openChat($user, $event)->json('data.id');

        $this->rsvp($user, $event, 'interested');
        $this->getJson("/api/v1/groups/{$groupId}/messages")->assertForbidden();

        $this->rsvp($user, $event, 'going');
        $this->getJson("/api/v1/groups/{$groupId}/messages")->assertOk();

        $this->deleteJson("/api/v1/events/{$event->id}/rsvp")->assertOk();
        $this->getJson("/api/v1/groups/{$groupId}/messages")->assertForbidden();
    }

    public function test_people_who_were_going_before_the_chat_existed_are_added(): void
    {
        $event = Event::factory()->create();
        $early = User::factory()->create();
        $this->rsvp($early, $event, 'going');

        $groupId = $this->openChat($event->host, $event)->json('data.id');

        $this->assertTrue(Group::find($groupId)->members()->whereKey($early->id)->exists());
    }

    public function test_event_chats_are_hidden_from_group_lists_and_search(): void
    {
        $event = Event::factory()->create(['title' => 'Seed swap social']);
        $this->openChat($event->host, $event)->assertOk();

        Sanctum::actingAs($event->host);
        $this->assertSame([], $this->getJson('/api/v1/groups')->assertOk()->json('data'));
        $this->assertSame([], $this->getJson('/api/v1/search?q=seed')->json('data.groups') ?? []);
    }

    public function test_drafts_have_no_chat_and_deleting_the_event_deletes_it(): void
    {
        $draft = Event::factory()->create(['status' => EventStatus::Draft]);
        $this->openChat($draft->host, $draft)->assertNotFound();

        $event = Event::factory()->create();
        $groupId = $this->openChat($event->host, $event)->json('data.id');
        $this->deleteJson("/api/v1/events/{$event->id}")->assertOk();

        $this->assertDatabaseMissing('groups', ['id' => $groupId]);
    }
}
