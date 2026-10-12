<?php

namespace Tests\Feature\Api;

use App\Enums\EventStatus;
use App\Enums\GroupMemberRole;
use App\Http\Controllers\Api\V1\RetiredFeatureController;
use App\Models\Comment;
use App\Models\Event;
use App\Models\Group;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AgroHubApiTest extends TestCase
{
    use RefreshDatabase;

    // --- Groups ---------------------------------------------------------

    public function test_an_admin_can_create_a_group_and_becomes_its_admin_member(): void
    {
        // Only site admins create groups — see GroupPolicy::create().
        $user = User::factory()->create(['is_admin' => true]);
        Sanctum::actingAs($user);

        $response = $this->postJson('/api/v1/groups', [
            'name' => 'Tomato Growers',
            'slug' => 'tomato-growers',
            'description' => 'For tomato enthusiasts.',
            'category' => 'Vegetable Growing',
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.slug', 'tomato-growers');
        $response->assertJsonPath('data.members_count', 1);
        $response->assertJsonPath('data.category', 'Vegetable Growing');

        $this->assertDatabaseHas('group_members', [
            'group_id' => $response->json('data.id'),
            'user_id' => $user->id,
            'role' => GroupMemberRole::Admin->value,
        ]);
    }

    public function test_group_categories_are_admin_managed_and_a_made_up_one_is_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create());

        // The seeded admin-managed list — see the group_categories migration.
        $categories = $this->getJson('/api/v1/group-categories');
        $categories->assertOk();
        $this->assertContains(
            'Vegetable Growing',
            collect($categories->json('data'))->pluck('name'),
        );

        $response = $this->postJson('/api/v1/groups', [
            'name' => 'Made Up Circle',
            'slug' => 'made-up-circle',
            'category' => 'Not A Real Category',
        ]);

        $response->assertUnprocessable();
        $response->assertJsonValidationErrors(['category']);
    }

    public function test_a_group_can_be_created_with_a_real_cover_and_avatar_image(): void
    {
        Storage::fake('public');

        $user = User::factory()->create(['is_admin' => true]);
        Sanctum::actingAs($user);

        $response = $this->post('/api/v1/groups', [
            'name' => 'Tomato Growers',
            'slug' => 'tomato-growers-avatar',
            'cover_image' => UploadedFile::fake()->image('cover.jpg'),
            'avatar' => UploadedFile::fake()->image('avatar.jpg'),
        ]);

        $response->assertCreated();
        $this->assertNotNull($response->json('data.cover_image_url'));
        $this->assertNotNull($response->json('data.avatar_url'));
    }

    public function test_the_group_index_reports_is_member_per_group_for_the_current_user(): void
    {
        $user = User::factory()->create();
        $joinedGroup = Group::factory()->create();
        $joinedGroup->members()->attach($user->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
        $otherGroup = Group::factory()->create();

        Sanctum::actingAs($user);

        $response = $this->getJson('/api/v1/groups');

        $response->assertOk();
        $byId = collect($response->json('data'))->keyBy('id');
        $this->assertTrue($byId[$joinedGroup->id]['is_member']);
        $this->assertFalse($byId[$otherGroup->id]['is_member']);
    }

    public function test_the_group_index_reports_todays_post_count_per_group(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $group = Group::factory()->create();
        Post::factory()->for($group)->create(['created_at' => now()]);
        Post::factory()->for($group)->create(['created_at' => now()]);
        Post::factory()->for($group)->create(['created_at' => now()->subDays(2)]);

        $response = $this->getJson('/api/v1/groups');

        $response->assertOk();
        $byId = collect($response->json('data'))->keyBy('id');
        $this->assertSame(2, $byId[$group->id]['posts_today_count']);
    }

    public function test_the_group_index_reports_a_last_message_preview_and_unread_count_that_clears_on_open(): void
    {
        $poster = User::factory()->create(['name' => 'Elena']);
        $group = Group::factory()->create();
        $group->members()->attach($poster->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now(), 'last_read_message_id' => 0]);

        $member = User::factory()->create();
        Sanctum::actingAs($member);
        $this->postJson("/api/v1/groups/{$group->id}/join")->assertOk();

        Sanctum::actingAs($poster);
        $this->postJson("/api/v1/groups/{$group->id}/messages", [
            'body' => 'Anyone free for a seed swap Saturday?',
        ])->assertCreated();

        Sanctum::actingAs($member);
        $indexBefore = $this->getJson('/api/v1/groups');
        $indexBefore->assertOk();
        $byId = collect($indexBefore->json('data'))->keyBy('id');
        $this->assertSame(1, $byId[$group->id]['unread_count']);
        $this->assertSame('Anyone free for a seed swap Saturday?', $byId[$group->id]['last_message']['body']);
        $this->assertSame('Elena', $byId[$group->id]['last_message']['sender_name']);

        // Opening the chat (GET messages) marks it read — same trigger as
        // MessageController::index() for the 1:1 swap-offer thread.
        $this->getJson("/api/v1/groups/{$group->id}/messages")->assertOk();

        $indexAfter = $this->getJson('/api/v1/groups');
        $indexAfter->assertOk();
        $this->assertSame(0, collect($indexAfter->json('data'))->keyBy('id')[$group->id]['unread_count']);
    }

    public function test_opening_a_long_group_chat_shows_the_most_recent_messages_not_the_oldest(): void
    {
        $group = Group::factory()->create();
        $poster = User::factory()->create();
        $group->members()->attach($poster->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now(), 'last_read_message_id' => 0]);
        Sanctum::actingAs($poster);

        // More than GroupMessageController::PER_PAGE (50) so the chat spans
        // more than one page.
        for ($i = 1; $i <= 55; $i++) {
            $message = $group->messages()->create(['body' => "Message {$i}"]);
            $message->sender_id = $poster->id;
            $message->created_at = now()->addSeconds($i);
            $message->save();
        }

        $response = $this->getJson("/api/v1/groups/{$group->id}/messages");
        $response->assertOk();
        $bodies = collect($response->json('data'))->pluck('body');

        // Opening the chat should land on the tail of the conversation —
        // like any real chat app — not page 1 of its oldest messages.
        $this->assertCount(50, $bodies);
        $this->assertSame('Message 55', $bodies->last());
        $this->assertNotContains('Message 1', $bodies->all());
    }

    public function test_only_the_creator_or_a_group_admin_can_update_a_group(): void
    {
        $creator = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $creator->id]);
        $group->members()->attach($creator->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);

        $outsider = User::factory()->create();
        Sanctum::actingAs($outsider);

        $this->patchJson("/api/v1/groups/{$group->id}", ['name' => 'Hijacked'])->assertForbidden();

        Sanctum::actingAs($creator);
        $this->patchJson("/api/v1/groups/{$group->id}", ['name' => 'Renamed'])
            ->assertOk()
            ->assertJsonPath('data.name', 'Renamed');
    }

    public function test_a_user_can_join_and_then_leave_a_group_via_the_api(): void
    {
        $group = Group::factory()->create();
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson("/api/v1/groups/{$group->id}/join")->assertOk();
        $this->assertDatabaseHas('group_members', ['group_id' => $group->id, 'user_id' => $user->id]);

        $this->postJson("/api/v1/groups/{$group->id}/join")->assertUnprocessable();

        $this->postJson("/api/v1/groups/{$group->id}/leave")->assertOk();
        $this->assertDatabaseMissing('group_members', ['group_id' => $group->id, 'user_id' => $user->id]);
    }

    public function test_the_group_creator_cannot_leave_their_own_group(): void
    {
        $creator = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $creator->id]);
        $group->members()->attach($creator->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);

        Sanctum::actingAs($creator);

        $this->postJson("/api/v1/groups/{$group->id}/leave")->assertUnprocessable();
    }

    public function test_group_members_lists_the_real_roster_with_admins_first_and_real_roles(): void
    {
        $admin = User::factory()->create(['name' => 'Admin Elena']);
        $group = Group::factory()->create(['created_by' => $admin->id]);
        $group->members()->attach($admin->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);

        $member = User::factory()->create(['name' => 'Carlos Mendoza']);
        $group->members()->attach($member->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);

        Sanctum::actingAs($member);

        $response = $this->getJson("/api/v1/groups/{$group->id}/members");

        $response->assertOk();
        $names = collect($response->json('data'))->pluck('name');
        $this->assertSame(['Admin Elena', 'Carlos Mendoza'], $names->all());
        $this->assertSame('admin', $response->json('data.0.role'));
        $this->assertSame('member', $response->json('data.1.role'));
    }

    public function test_an_admin_can_pin_and_then_clear_a_group_message_but_a_member_cannot(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        $group->members()->attach($admin->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);

        $member = User::factory()->create();
        $group->members()->attach($member->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);

        Sanctum::actingAs($member);
        $this->patchJson("/api/v1/groups/{$group->id}", ['pinned_message' => 'Hijacked pin'])
            ->assertForbidden();

        Sanctum::actingAs($admin);
        $response = $this->patchJson("/api/v1/groups/{$group->id}", [
            'pinned_message' => 'Seed swap meetup Saturday at 10 AM.',
        ]);
        $response->assertOk();
        $response->assertJsonPath('data.pinned_message', 'Seed swap meetup Saturday at 10 AM.');
        $response->assertJsonPath('data.pinned_by.id', $admin->id);
        $this->assertNotNull($response->json('data.pinned_at'));

        $cleared = $this->patchJson("/api/v1/groups/{$group->id}", ['pinned_message' => '']);
        $cleared->assertOk();
        $cleared->assertJsonPath('data.pinned_message', null);
        $this->assertNull($cleared->json('data.pinned_by'));
    }

    public function test_a_group_member_can_send_and_list_real_time_chat_messages(): void
    {
        $group = Group::factory()->create();
        $sender = User::factory()->create();
        $group->members()->attach($sender->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);

        Sanctum::actingAs($sender);

        $response = $this->postJson("/api/v1/groups/{$group->id}/messages", [
            'body' => 'Anyone tried neem spray on aphids?',
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.body', 'Anyone tried neem spray on aphids?');
        $response->assertJsonPath('data.sender.id', $sender->id);
        $response->assertJsonPath('data.sender_is_admin', false);

        $index = $this->getJson("/api/v1/groups/{$group->id}/messages");
        $index->assertOk();
        $index->assertJsonCount(1, 'data');
    }

    public function test_a_group_chat_message_can_be_sent_with_only_an_image(): void
    {
        Storage::fake('public');

        $group = Group::factory()->create();
        $sender = User::factory()->create();
        $group->members()->attach($sender->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);
        Sanctum::actingAs($sender);

        $response = $this->post("/api/v1/groups/{$group->id}/messages", [
            'image' => UploadedFile::fake()->image('bloom.jpg'),
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.body', null);
        $response->assertJsonPath('data.sender_is_admin', true);
        $this->assertNotNull($response->json('data.image_url'));
    }

    public function test_a_non_member_cannot_view_or_send_group_chat_messages(): void
    {
        $group = Group::factory()->create();
        $outsider = User::factory()->create();
        Sanctum::actingAs($outsider);

        $this->getJson("/api/v1/groups/{$group->id}/messages")->assertForbidden();
        $this->postJson("/api/v1/groups/{$group->id}/messages", ['body' => 'Let me in?'])->assertForbidden();
    }

    // --- Posts & Comments -------------------------------------------------

    public function test_posting_into_a_group_requires_membership(): void
    {
        $group = Group::factory()->create();
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/posts', ['group_id' => $group->id, 'body' => 'Hello group'])
            ->assertUnprocessable();

        $group->members()->attach($user->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);

        $this->postJson('/api/v1/posts', ['group_id' => $group->id, 'body' => 'Hello group'])
            ->assertCreated()
            ->assertJsonPath('data.group_id', $group->id);
    }

    public function test_a_user_can_like_and_unlike_a_post(): void
    {
        $post = Post::factory()->create();
        $liker = User::factory()->create();
        Sanctum::actingAs($liker);

        $this->postJson("/api/v1/posts/{$post->id}/like")
            ->assertOk()
            ->assertJsonPath('data.likes_count', 1)
            ->assertJsonPath('data.liked_by_me', true);

        $this->assertDatabaseHas('post_likes', ['post_id' => $post->id, 'user_id' => $liker->id]);

        $this->deleteJson("/api/v1/posts/{$post->id}/like")
            ->assertOk()
            ->assertJsonPath('data.likes_count', 0)
            ->assertJsonPath('data.liked_by_me', false);

        $this->assertDatabaseMissing('post_likes', ['post_id' => $post->id, 'user_id' => $liker->id]);
    }

    public function test_liking_a_post_twice_does_not_double_count(): void
    {
        $post = Post::factory()->create();
        Sanctum::actingAs(User::factory()->create());

        $this->postJson("/api/v1/posts/{$post->id}/like")->assertOk();
        $this->postJson("/api/v1/posts/{$post->id}/like")
            ->assertOk()
            ->assertJsonPath('data.likes_count', 1);
    }

    public function test_a_user_can_reply_to_a_top_level_comment(): void
    {
        $post = Post::factory()->create();
        $original = User::factory()->create(['name' => 'Elena Rostova']);
        Sanctum::actingAs($original);
        $topLevelId = $this->postJson("/api/v1/posts/{$post->id}/comments", ['body' => 'Great progress!'])
            ->json('data.id');

        $replier = User::factory()->create();
        Sanctum::actingAs($replier);

        $response = $this->postJson("/api/v1/posts/{$post->id}/comments", [
            'body' => 'Thanks so much!',
            'reply_to_comment_id' => $topLevelId,
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.parent_id', $topLevelId);
        $response->assertJsonPath('data.replying_to_name', 'Elena Rostova');
    }

    public function test_replying_to_a_reply_flattens_into_the_same_top_level_thread(): void
    {
        $post = Post::factory()->create();
        $original = User::factory()->create(['name' => 'Elena Rostova']);
        Sanctum::actingAs($original);
        $topLevelId = $this->postJson("/api/v1/posts/{$post->id}/comments", ['body' => 'Great progress!'])
            ->json('data.id');

        $firstReplier = User::factory()->create(['name' => 'David Chen']);
        Sanctum::actingAs($firstReplier);
        $replyId = $this->postJson("/api/v1/posts/{$post->id}/comments", [
            'body' => 'Thanks so much!',
            'reply_to_comment_id' => $topLevelId,
        ])->json('data.id');

        $secondReplier = User::factory()->create();
        Sanctum::actingAs($secondReplier);
        $response = $this->postJson("/api/v1/posts/{$post->id}/comments", [
            'body' => 'Agreed with David!',
            'reply_to_comment_id' => $replyId,
        ]);

        $response->assertCreated();
        // Still grouped under the ORIGINAL top-level comment, not nested
        // under the reply — one flat level, same as Facebook/Instagram.
        $response->assertJsonPath('data.parent_id', $topLevelId);
        // But the bold-name credit goes to the specific person replied to.
        $response->assertJsonPath('data.replying_to_name', 'David Chen');
    }

    public function test_replying_to_a_comment_on_a_different_post_is_rejected(): void
    {
        $postA = Post::factory()->create();
        $postB = Post::factory()->create();
        $commentOnA = Comment::factory()->for($postA)->create();

        Sanctum::actingAs(User::factory()->create());

        $this->postJson("/api/v1/posts/{$postB->id}/comments", [
            'body' => 'Wrong thread!',
            'reply_to_comment_id' => $commentOnA->id,
        ])->assertUnprocessable();
    }

    public function test_deleting_a_top_level_comment_cascades_to_its_replies(): void
    {
        $post = Post::factory()->create();
        $author = User::factory()->create();
        Sanctum::actingAs($author);
        $topLevelId = $this->postJson("/api/v1/posts/{$post->id}/comments", ['body' => 'Original'])
            ->json('data.id');
        $replyId = $this->postJson("/api/v1/posts/{$post->id}/comments", [
            'body' => 'A reply',
            'reply_to_comment_id' => $topLevelId,
        ])->json('data.id');

        $this->deleteJson("/api/v1/comments/{$topLevelId}")->assertOk();

        $this->assertDatabaseMissing('comments', ['id' => $topLevelId]);
        $this->assertDatabaseMissing('comments', ['id' => $replyId]);
    }

    public function test_a_user_can_comment_on_a_post_and_only_the_author_can_delete_their_comment(): void
    {
        $post = Post::factory()->create();
        $author = User::factory()->create();
        Sanctum::actingAs($author);

        $created = $this->postJson("/api/v1/posts/{$post->id}/comments", ['body' => 'Nice plant!']);
        $created->assertCreated();
        $commentId = $created->json('data.id');

        $other = User::factory()->create();
        Sanctum::actingAs($other);
        $this->deleteJson("/api/v1/comments/{$commentId}")->assertForbidden();

        Sanctum::actingAs($author);
        $this->deleteJson("/api/v1/comments/{$commentId}")->assertOk();
        $this->assertDatabaseMissing('comments', ['id' => $commentId]);
    }

    public function test_a_posts_owner_can_delete_a_comment_someone_else_left_on_it(): void
    {
        $postOwner = User::factory()->create();
        $post = Post::factory()->create(['author_id' => $postOwner->id]);

        $commenter = User::factory()->create();
        Sanctum::actingAs($commenter);
        $created = $this->postJson("/api/v1/posts/{$post->id}/comments", ['body' => 'Nice plant!']);
        $created->assertCreated();
        $commentId = $created->json('data.id');

        Sanctum::actingAs($postOwner);
        $this->deleteJson("/api/v1/comments/{$commentId}")->assertOk();
        $this->assertDatabaseMissing('comments', ['id' => $commentId]);
    }

    public function test_a_post_can_be_updated_by_its_author_only(): void
    {
        $author = User::factory()->create();
        $post = Post::factory()->create([
            'author_id' => $author->id,
            'body' => 'Original body',
        ]);

        $other = User::factory()->create();
        Sanctum::actingAs($other);
        $this->patchJson("/api/v1/posts/{$post->id}", ['body' => 'Hijacked'])->assertForbidden();

        Sanctum::actingAs($author);
        $response = $this->patchJson("/api/v1/posts/{$post->id}", ['body' => 'Updated body']);

        $response->assertOk();
        $response->assertJsonPath('data.body', 'Updated body');
        $this->assertDatabaseHas('posts', ['id' => $post->id, 'body' => 'Updated body']);
    }

    public function test_removing_a_posts_image_clears_it(): void
    {
        $author = User::factory()->create();
        $post = Post::factory()->create([
            'author_id' => $author->id,
            'image_path' => 'posts/existing.jpg',
        ]);
        Sanctum::actingAs($author);

        $response = $this->patchJson("/api/v1/posts/{$post->id}", ['remove_image' => true]);

        $response->assertOk();
        $response->assertJsonPath('data.image_url', null);
        $this->assertDatabaseHas('posts', ['id' => $post->id, 'image_path' => null]);
    }

    // --- Events -----------------------------------------------------------

    public function test_a_user_can_create_a_published_event_and_others_can_rsvp(): void
    {
        $host = User::factory()->create();
        Sanctum::actingAs($host);

        $created = $this->postJson('/api/v1/events', [
            'title' => 'Community Compost Workshop',
            'format' => 'in_person',
            'location' => 'Community Garden',
            'starts_at' => now()->addWeek()->toIso8601String(),
            'status' => 'published',
        ]);
        $created->assertCreated();
        $eventId = $created->json('data.id');

        $attendee = User::factory()->create();
        Sanctum::actingAs($attendee);

        $this->postJson("/api/v1/events/{$eventId}/rsvp", ['status' => 'going'])
            ->assertOk()
            ->assertJsonPath('data.attendees_count', 1);

        $this->deleteJson("/api/v1/events/{$eventId}/rsvp")->assertOk();
        $this->assertDatabaseMissing('event_attendees', ['event_id' => $eventId, 'user_id' => $attendee->id]);
    }

    public function test_the_events_index_reports_my_rsvp_status_per_event(): void
    {
        $host = User::factory()->create();
        Sanctum::actingAs($host);

        $goingId = $this->postJson('/api/v1/events', [
            'title' => 'Compost Workshop',
            'format' => 'in_person',
            'starts_at' => now()->addWeek()->toIso8601String(),
            'status' => 'published',
        ])->json('data.id');

        $notGoingId = $this->postJson('/api/v1/events', [
            'title' => 'Seed Swap',
            'format' => 'in_person',
            'starts_at' => now()->addWeeks(2)->toIso8601String(),
            'status' => 'published',
        ])->json('data.id');

        $this->postJson("/api/v1/events/{$goingId}/rsvp", ['status' => 'going'])->assertOk();

        $response = $this->getJson('/api/v1/events');

        $response->assertOk();
        $byId = collect($response->json('data'))->keyBy('id');
        $this->assertSame('going', $byId[$goingId]['my_rsvp_status']);
        $this->assertNull($byId[$notGoingId]['my_rsvp_status']);
    }

    public function test_only_the_host_can_update_or_delete_their_event(): void
    {
        $event = Event::factory()->create(['status' => EventStatus::Published]);
        $outsider = User::factory()->create();
        Sanctum::actingAs($outsider);

        $this->patchJson("/api/v1/events/{$event->id}", ['title' => 'Hijacked'])->assertForbidden();
        $this->deleteJson("/api/v1/events/{$event->id}")->assertForbidden();
    }

    public function test_the_events_index_only_lists_published_events(): void
    {
        Event::factory()->create(['status' => EventStatus::Published]);
        Event::factory()->create(['status' => EventStatus::Draft]);

        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/events');

        $response->assertOk();
        $response->assertJsonCount(1, 'data');
    }

    public function test_the_events_index_excludes_events_that_have_already_ended(): void
    {
        $upcoming = Event::factory()->create([
            'status' => EventStatus::Published,
            'starts_at' => now()->addDay(),
            'ends_at' => now()->addDay()->addHours(2),
        ]);
        Event::factory()->create([
            'status' => EventStatus::Published,
            'starts_at' => now()->subDays(3),
            'ends_at' => now()->subDays(3)->addHours(2),
        ]);

        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/events');

        $response->assertOk();
        $response->assertJsonCount(1, 'data');
        $response->assertJsonPath('data.0.id', $upcoming->id);
    }

    public function test_the_events_index_still_shows_an_event_that_is_underway_but_not_yet_ended(): void
    {
        $ongoing = Event::factory()->create([
            'status' => EventStatus::Published,
            'starts_at' => now()->subHour(),
            'ends_at' => now()->addHour(),
        ]);

        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/events');

        $response->assertOk();
        $response->assertJsonCount(1, 'data');
        $response->assertJsonPath('data.0.id', $ongoing->id);
    }

    public function test_the_events_index_excludes_a_started_event_with_no_end_time_once_its_start_time_passes(): void
    {
        Event::factory()->create([
            'status' => EventStatus::Published,
            'starts_at' => now()->subHour(),
            'ends_at' => null,
        ]);

        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/events');

        $response->assertOk();
        $response->assertJsonCount(0, 'data');
    }

    public function test_the_calendar_month_view_still_shows_expired_events_in_a_past_month(): void
    {
        $pastEvent = Event::factory()->create([
            'status' => EventStatus::Published,
            'starts_at' => '2026-06-15 18:00:00',
            'ends_at' => '2026-06-15 20:00:00',
        ]);

        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/events?month=2026-06');

        $response->assertOk();
        $response->assertJsonCount(1, 'data');
        $response->assertJsonPath('data.0.id', $pastEvent->id);
    }

    public function test_event_categories_are_admin_managed_and_a_made_up_one_is_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create());

        // The seeded admin-managed list — see the event_categories migration.
        $categories = $this->getJson('/api/v1/event-categories');
        $categories->assertOk();
        $names = collect($categories->json('data'))->pluck('name');
        $this->assertContains('Workshop', $names);
        $this->assertContains('Field Day & Farm Tour', $names);

        $response = $this->postJson('/api/v1/events', [
            'title' => 'Community Compost Workshop',
            'format' => 'in_person',
            'starts_at' => now()->addWeek()->toIso8601String(),
            'category' => 'Not A Real Category',
        ]);

        $response->assertUnprocessable();
        $response->assertJsonValidationErrors(['category']);
    }

    public function test_an_event_can_be_created_with_a_real_category(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->postJson('/api/v1/events', [
            'title' => 'Grafting & Pruning Field Day',
            'format' => 'in_person',
            'starts_at' => now()->addWeek()->toIso8601String(),
            'category' => 'Field Day & Farm Tour',
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.category', 'Field Day & Farm Tour');
    }

    public function test_an_event_can_be_created_with_no_category(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->postJson('/api/v1/events', [
            'title' => 'Community Compost Workshop',
            'format' => 'in_person',
            'starts_at' => now()->addWeek()->toIso8601String(),
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.category', null);
    }

    public function test_the_events_index_category_filter_only_returns_matching_events(): void
    {
        $workshop = Event::factory()->create([
            'status' => EventStatus::Published,
            'category' => 'Workshop',
        ]);
        Event::factory()->create([
            'status' => EventStatus::Published,
            'category' => 'Volunteer Day',
        ]);
        Event::factory()->create([
            'status' => EventStatus::Published,
            'category' => null,
        ]);

        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/events?category='.urlencode('Workshop'));

        $response->assertOk();
        $response->assertJsonCount(1, 'data');
        $response->assertJsonPath('data.0.id', $workshop->id);
    }

    public function test_the_events_index_with_no_category_filter_returns_every_category(): void
    {
        Event::factory()->create(['status' => EventStatus::Published, 'category' => 'Workshop']);
        Event::factory()->create(['status' => EventStatus::Published, 'category' => 'Volunteer Day']);
        Event::factory()->create(['status' => EventStatus::Published, 'category' => null]);

        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/events');

        $response->assertOk();
        $response->assertJsonCount(3, 'data');
    }

    public function test_the_events_index_month_filter_only_returns_events_in_that_calendar_month(): void
    {
        $juneEvent = Event::factory()->create([
            'status' => EventStatus::Published,
            'starts_at' => '2026-06-15 18:00:00',
        ]);
        Event::factory()->create([
            'status' => EventStatus::Published,
            'starts_at' => '2026-07-01 09:00:00',
        ]);
        Event::factory()->create([
            'status' => EventStatus::Published,
            'starts_at' => '2026-05-31 23:00:00',
        ]);

        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/events?month=2026-06');

        $response->assertOk();
        $response->assertJsonCount(1, 'data');
        $response->assertJsonPath('data.0.id', $juneEvent->id);
    }

    public function test_the_events_index_rejects_a_badly_formatted_month(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->getJson('/api/v1/events?month=not-a-month')
            ->assertUnprocessable();
    }

    public function test_a_user_can_save_and_unsave_an_event(): void
    {
        $event = Event::factory()->create(['status' => EventStatus::Published]);
        Sanctum::actingAs(User::factory()->create());

        $this->getJson("/api/v1/events/{$event->id}")
            ->assertOk()
            ->assertJsonPath('data.is_saved', false);

        $this->postJson("/api/v1/events/{$event->id}/save")
            ->assertOk()
            ->assertJsonPath('data.is_saved', true);

        $indexed = $this->getJson('/api/v1/events')->json('data');
        $this->assertTrue(collect($indexed)->firstWhere('id', $event->id)['is_saved']);

        $this->deleteJson("/api/v1/events/{$event->id}/save")
            ->assertOk()
            ->assertJsonPath('data.is_saved', false);
    }

    public function test_saved_events_returns_only_what_the_user_saved_most_recent_first(): void
    {
        $saver = User::factory()->create();
        Sanctum::actingAs($saver);

        $first = Event::factory()->create(['status' => EventStatus::Published]);
        $second = Event::factory()->create(['status' => EventStatus::Published]);
        $neverSaved = Event::factory()->create(['status' => EventStatus::Published]);

        $this->postJson("/api/v1/events/{$first->id}/save")->assertOk();
        $this->postJson("/api/v1/events/{$second->id}/save")->assertOk();

        $response = $this->getJson('/api/v1/events/saved');

        $response->assertOk();
        $ids = collect($response->json('data'))->pluck('id')->all();
        $this->assertSame([$second->id, $first->id], $ids);
        $this->assertNotContains($neverSaved->id, $ids);
        $response->assertJsonPath('data.0.is_saved', true);
    }

    public function test_saved_events_still_shows_an_event_that_has_already_ended(): void
    {
        $saver = User::factory()->create();
        $event = Event::factory()->create([
            'status' => EventStatus::Published,
            'starts_at' => now()->subWeek(),
            'ends_at' => now()->subWeek()->addHours(2),
        ]);
        $event->savedBy()->attach($saver->id);

        Sanctum::actingAs($saver);
        $response = $this->getJson('/api/v1/events/saved');

        $response->assertOk();
        $this->assertSame([$event->id], collect($response->json('data'))->pluck('id')->all());
    }

    public function test_the_event_detail_endpoint_returns_a_preview_of_real_attendees(): void
    {
        $event = Event::factory()->create(['status' => EventStatus::Published]);
        $host = $event->host;
        $attendee = User::factory()->create(['name' => 'Elena Rostova']);
        $event->attendees()->attach($attendee->id, [
            'status' => 'going',
            'rsvped_at' => now(),
        ]);

        Sanctum::actingAs($host);

        $response = $this->getJson("/api/v1/events/{$event->id}");

        $response->assertOk();
        $preview = $response->json('data.attendees_preview');
        $this->assertCount(1, $preview);
        $this->assertSame('Elena Rostova', $preview[0]['name']);
        $this->assertSame($event->attendees()->count(), $response->json('data.attendees_count'));
    }

    // --- Agri-AI (removed) ------------------------------------------------

    public function test_events_can_be_searched_and_ones_near_the_user_come_first(): void
    {
        $user = User::factory()->create(['address_city' => 'Luton']);
        $host = User::factory()->create(['name' => 'Rooftop Farmers']);
        $far = Event::factory()->create(['title' => 'Seed swap', 'location' => 'Mirpur, Dhaka', 'host_id' => $host->id, 'starts_at' => now()->addDay(), 'ends_at' => now()->addDay()->addHours(2)]);
        $near = Event::factory()->create(['title' => 'Compost workshop', 'location' => 'Wardown Park, Luton', 'starts_at' => now()->addDays(5), 'ends_at' => now()->addDays(5)->addHours(2)]);

        Sanctum::actingAs($user);

        $all = $this->getJson('/api/v1/events?for_you=1')->assertOk()->json('data');
        $this->assertSame([$near->id, $far->id], array_column($all, 'id'));
        $this->assertSame([true, false], array_column($all, 'is_near_you'));

        $this->assertSame([$near->id], array_column($this->getJson('/api/v1/events?search=compost')->json('data'), 'id'));
        $this->assertSame([$far->id], array_column($this->getJson('/api/v1/events?search=rooftop')->json('data'), 'id'));
        $this->assertSame([$near->id], array_column($this->getJson('/api/v1/events?search=luton')->json('data'), 'id'));
    }

    public function test_events_can_be_narrowed_to_ones_the_user_is_going_to(): void
    {
        $user = User::factory()->create();
        $going = Event::factory()->create(['starts_at' => now()->addDay(), 'ends_at' => now()->addDay()->addHour()]);
        Event::factory()->create(['starts_at' => now()->addDay(), 'ends_at' => now()->addDay()->addHour()]);

        Sanctum::actingAs($user);
        $this->postJson("/api/v1/events/{$going->id}/rsvp", ['status' => 'going'])->assertOk();

        $this->assertSame([$going->id], array_column($this->getJson('/api/v1/events?going=1')->json('data'), 'id'));
    }

    public function test_removed_features_answer_old_apps_with_a_readable_message(): void
    {
        $post = Post::factory()->create();
        Sanctum::actingAs(User::factory()->create());

        foreach ([
            // Agri-AI and its Premium subscription
            ['GET', '/api/v1/ai/conversations'],
            ['GET', '/api/v1/ai/conversations/1'],
            ['POST', '/api/v1/ai/messages'],
            ['GET', '/api/v1/subscriptions/me'],
            ['POST', '/api/v1/subscriptions'],
            ['DELETE', '/api/v1/subscriptions/me'],
            ['GET', '/api/v1/config/stripe-key'],
            // The personal Home timeline
            ['GET', '/api/v1/feed'],
            ['GET', '/api/v1/post-categories'],
            ['POST', "/api/v1/posts/{$post->id}/share"],
        ] as [$method, $uri]) {
            $this->json($method, $uri)
                ->assertStatus(410)
                ->assertJsonPath('message', RetiredFeatureController::MESSAGE);
        }

    }
}
