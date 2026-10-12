<?php

namespace Tests\Feature\AgroHub;

use App\Enums\EventAttendeeStatus;
use App\Enums\EventFormat;
use App\Enums\EventStatus;
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
}
