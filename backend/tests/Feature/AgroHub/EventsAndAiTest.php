<?php

namespace Tests\Feature\AgroHub;

use App\Enums\AiMessageRole;
use App\Enums\EventAttendeeStatus;
use App\Enums\EventFormat;
use App\Enums\EventStatus;
use App\Models\AiConversation;
use App\Models\AiMessage;
use App\Models\Event;
use App\Models\Group;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class EventsAndAiTest extends TestCase
{
    use RefreshDatabase;

    public function test_an_event_can_be_created_with_each_format_and_status(): void
    {
        foreach (EventFormat::cases() as $format) {
            foreach (EventStatus::cases() as $status) {
                $event = Event::factory()->create(['format' => $format, 'status' => $status]);

                $this->assertSame($format, $event->fresh()->format);
                $this->assertSame($status, $event->fresh()->status);
            }
        }
    }

    public function test_an_event_can_optionally_belong_to_a_group(): void
    {
        $group = Group::factory()->create();
        $event = Event::factory()->create(['group_id' => $group->id]);

        $this->assertSame($group->id, $event->fresh()->group->id);
        $this->assertTrue($group->fresh()->events->contains($event));
    }

    public function test_a_user_can_rsvp_to_an_event_and_cannot_rsvp_twice(): void
    {
        $event = Event::factory()->create();
        $user = User::factory()->create();

        $event->attendees()->attach($user->id, [
            'status' => EventAttendeeStatus::Going,
            'rsvped_at' => now(),
        ]);

        $this->assertTrue($event->fresh()->attendees->contains($user));
        $this->assertSame(EventAttendeeStatus::Going, $event->attendees()->first()->pivot->status);

        $this->expectException(QueryException::class);
        $event->attendees()->attach($user->id, [
            'status' => EventAttendeeStatus::Interested,
            'rsvped_at' => now(),
        ]);
    }

    public function test_deleting_an_event_cascades_to_its_rsvps(): void
    {
        $event = Event::factory()->create();
        $user = User::factory()->create();
        $event->attendees()->attach($user->id, ['status' => EventAttendeeStatus::Going, 'rsvped_at' => now()]);

        $event->delete();

        $this->assertDatabaseMissing('event_attendees', ['event_id' => $event->id]);
    }

    public function test_an_ai_conversation_holds_an_ordered_mixed_role_message_thread(): void
    {
        $conversation = AiConversation::factory()->create();

        $userMessage = AiMessage::factory()->for($conversation, 'conversation')->create([
            'role' => AiMessageRole::User,
            'body' => 'Why are my tomato leaves curling?',
        ]);

        $assistantMessage = AiMessage::factory()->for($conversation, 'conversation')->create([
            'role' => AiMessageRole::Assistant,
            'body' => 'That can be heat stress or aphids — can you share a photo of the leaf?',
        ]);

        $messages = $conversation->fresh()->messages()->orderBy('created_at')->get();

        $this->assertCount(2, $messages);
        $this->assertSame(AiMessageRole::User, $messages->first()->role);
        $this->assertSame($userMessage->id, $messages->first()->id);
        $this->assertSame(AiMessageRole::Assistant, $messages->last()->role);
        $this->assertSame($assistantMessage->id, $messages->last()->id);
    }

    public function test_an_ai_message_can_carry_a_leaf_diagnosis_photo(): void
    {
        $message = AiMessage::factory()->create([
            'role' => AiMessageRole::User,
            'image_path' => 'ai-uploads/leaf-123.jpg',
        ]);

        $this->assertSame('ai-uploads/leaf-123.jpg', $message->fresh()->image_path);
    }
}
