<?php

namespace Tests\Feature\Api;

use App\Enums\EventStatus;
use App\Models\Event;
use App\Models\Group;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class EventExtrasTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_new_event_categories_exist(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $names = collect($this->getJson('/api/v1/event-categories')->assertOk()->json('data'))->pluck('name');

        foreach (['Open Day', 'Seed Swap', 'Plant Fair', 'Nature Walk', 'Other'] as $name) {
            $this->assertContains($name, $names);
        }
    }

    public function test_an_event_saves_its_registration_fee_and_proposed_dates(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->postJson('/api/v1/events', [
            'title' => 'Seed swap',
            'format' => 'in_person',
            'category' => 'Seed Swap',
            'starts_at' => '2026-11-07T10:00:00Z',
            'registration_fee' => 3.5,
            'proposed_dates' => ['2026-11-14T10:00:00Z', '2026-11-21T10:00:00Z'],
            'status' => 'published',
        ])->assertCreated();

        $response->assertJsonPath('data.registration_fee', 3.5);
        $this->assertCount(2, $response->json('data.proposed_dates'));
        $this->assertStringStartsWith('2026-11-14T10:00:00', $response->json('data.proposed_dates.0'));

        $id = $response->json('data.id');
        $this->patchJson("/api/v1/events/{$id}", ['registration_fee' => null, 'proposed_dates' => []])
            ->assertOk()
            ->assertJsonPath('data.registration_fee', null)
            ->assertJsonPath('data.proposed_dates', []);
    }

    public function test_a_registration_fee_cannot_be_negative(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/events', [
            'title' => 'Seed swap',
            'format' => 'in_person',
            'starts_at' => '2026-11-07T10:00:00Z',
            'registration_fee' => -1,
        ])->assertUnprocessable()->assertJsonValidationErrors('registration_fee');
    }

    public function test_my_drafts_lists_only_my_own_draft_events(): void
    {
        $me = User::factory()->create();
        $draft = Event::factory()->create(['host_id' => $me->id, 'status' => EventStatus::Draft]);
        Event::factory()->create(['host_id' => $me->id, 'status' => EventStatus::Published]);
        Event::factory()->create(['status' => EventStatus::Draft]);
        Sanctum::actingAs($me);

        $ids = collect($this->getJson('/api/v1/events/mine?status=draft')->assertOk()->json('data'))->pluck('id');

        $this->assertSame([$draft->id], $ids->all());
        $this->assertCount(2, $this->getJson('/api/v1/events/mine')->json('data'));
    }

    public function test_for_you_puts_events_from_my_groups_first(): void
    {
        $me = User::factory()->create();
        $group = Group::factory()->create();
        $group->members()->attach($me->id, ['role' => 'member', 'joined_at' => now(), 'last_read_message_id' => 0]);
        $soonest = Event::factory()->create(['starts_at' => now()->addDay(), 'ends_at' => null]);
        $mine = Event::factory()->create(['group_id' => $group->id, 'starts_at' => now()->addWeek(), 'ends_at' => null]);
        Sanctum::actingAs($me);

        $ids = collect($this->getJson('/api/v1/events?for_you=1')->assertOk()->json('data'))->pluck('id');
        $this->assertSame([$mine->id, $soonest->id], $ids->all());

        $ids = collect($this->getJson('/api/v1/events')->json('data'))->pluck('id');
        $this->assertSame([$soonest->id, $mine->id], $ids->all());
    }

    public function test_anyone_can_review_or_comment_on_an_event(): void
    {
        $event = Event::factory()->create();
        $me = User::factory()->create();
        Sanctum::actingAs($me);

        $this->postJson("/api/v1/events/{$event->id}/reviews", ['rating' => 5, 'body' => 'Lovely day'])
            ->assertCreated()
            ->assertJsonPath('data.rating', 5)
            ->assertJsonPath('data.user.id', $me->id);
        $this->postJson("/api/v1/events/{$event->id}/reviews", ['body' => 'Can I bring seeds?'])
            ->assertCreated()
            ->assertJsonPath('data.rating', null);

        $this->assertCount(2, $this->getJson("/api/v1/events/{$event->id}/reviews")->assertOk()->json('data'));
    }

    public function test_a_review_needs_a_rating_or_a_comment(): void
    {
        $event = Event::factory()->create();
        Sanctum::actingAs(User::factory()->create());

        $this->postJson("/api/v1/events/{$event->id}/reviews", [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['rating', 'body']);
        $this->postJson("/api/v1/events/{$event->id}/reviews", ['rating' => 6])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('rating');
    }

    public function test_drafts_cannot_be_reviewed(): void
    {
        $event = Event::factory()->create(['status' => EventStatus::Draft]);
        Sanctum::actingAs(User::factory()->create());

        $this->postJson("/api/v1/events/{$event->id}/reviews", ['body' => 'Hi'])->assertNotFound();
    }

    public function test_only_the_author_can_delete_a_review(): void
    {
        $event = Event::factory()->create();
        $author = User::factory()->create();
        Sanctum::actingAs($author);
        $id = $this->postJson("/api/v1/events/{$event->id}/reviews", ['body' => 'Nice'])->json('data.id');

        Sanctum::actingAs(User::factory()->create());
        $this->deleteJson("/api/v1/events/{$event->id}/reviews/{$id}")->assertForbidden();

        Sanctum::actingAs($author);
        $this->deleteJson("/api/v1/events/{$event->id}/reviews/{$id}")->assertOk();
        $this->assertDatabaseMissing('event_reviews', ['id' => $id]);
    }
}
