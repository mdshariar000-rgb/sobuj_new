<?php

namespace Tests\Feature\Api;

use App\Enums\GroupMemberRole;
use App\Enums\ReportStatus;
use App\Models\Comment;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\Listing;
use App\Models\Post;
use App\Models\Report;
use App\Models\SwapOffer;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class TrustAndSafetyTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_can_report_a_post(): void
    {
        $reporter = User::factory()->create();
        $post = Post::factory()->create();
        Sanctum::actingAs($reporter);

        $this->postJson('/api/v1/reports', [
            'target_type' => 'post',
            'target_id' => $post->id,
            'reason' => 'spam',
            'details' => 'Looks like an ad.',
        ])->assertCreated();

        $this->assertDatabaseHas('reports', [
            'reporter_id' => $reporter->id,
            'target_type' => 'post',
            'target_id' => $post->id,
            'reason' => 'spam',
            'status' => 'pending',
        ]);
    }

    public function test_reporting_the_same_item_twice_is_idempotent(): void
    {
        $reporter = User::factory()->create();
        $comment = Comment::factory()->create();
        Sanctum::actingAs($reporter);

        $payload = ['target_type' => 'comment', 'target_id' => $comment->id, 'reason' => 'harassment'];

        $this->postJson('/api/v1/reports', $payload)->assertCreated();
        $this->postJson('/api/v1/reports', $payload)->assertOk();

        $this->assertSame(1, Report::query()->count());
    }

    public function test_reporting_a_listing_flags_it_for_the_moderation_queue(): void
    {
        $listing = Listing::factory()->create(['is_flagged' => false]);
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/reports', [
            'target_type' => 'listing',
            'target_id' => $listing->id,
            'reason' => 'illegal',
        ])->assertCreated();

        $this->assertTrue($listing->fresh()->is_flagged);
    }

    public function test_you_cannot_report_your_own_content_or_yourself(): void
    {
        $user = User::factory()->create();
        $ownPost = Post::factory()->create(['author_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/reports', [
            'target_type' => 'post', 'target_id' => $ownPost->id, 'reason' => 'spam',
        ])->assertUnprocessable()->assertJsonValidationErrors('target_id');

        $this->postJson('/api/v1/reports', [
            'target_type' => 'user', 'target_id' => $user->id, 'reason' => 'spam',
        ])->assertUnprocessable()->assertJsonValidationErrors('target_id');
    }

    public function test_reporting_a_missing_item_or_invalid_reason_is_rejected(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/reports', [
            'target_type' => 'post', 'target_id' => 999999, 'reason' => 'spam',
        ])->assertUnprocessable()->assertJsonValidationErrors('target_id');

        $this->postJson('/api/v1/reports', [
            'target_type' => 'post', 'target_id' => 1, 'reason' => 'because',
        ])->assertUnprocessable()->assertJsonValidationErrors('reason');
    }

    public function test_blocking_hides_the_blocked_users_posts_from_the_feed_both_ways(): void
    {
        $me = User::factory()->create();
        $blocked = User::factory()->create();
        $other = User::factory()->create();
        $blockedPost = Post::factory()->create(['author_id' => $blocked->id]);
        $otherPost = Post::factory()->create(['author_id' => $other->id]);

        Sanctum::actingAs($me);
        $this->postJson("/api/v1/users/{$blocked->id}/block")->assertOk();

        $ids = collect($this->getJson('/api/v1/feed')->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($otherPost->id));
        $this->assertFalse($ids->contains($blockedPost->id));

        // The blocked user can't see the blocker's posts either.
        $myPost = Post::factory()->create(['author_id' => $me->id]);
        Sanctum::actingAs($blocked);
        $ids = collect($this->getJson('/api/v1/feed')->json('data'))->pluck('id');
        $this->assertFalse($ids->contains($myPost->id));
    }

    public function test_blocking_is_idempotent_and_can_be_undone(): void
    {
        $me = User::factory()->create();
        $target = User::factory()->create();
        Sanctum::actingAs($me);

        $this->postJson("/api/v1/users/{$target->id}/block")->assertOk();
        $this->postJson("/api/v1/users/{$target->id}/block")->assertOk();
        $this->assertSame(1, $me->blockedUsers()->count());

        $this->getJson('/api/v1/blocks')->assertOk()->assertJsonPath('data.0.id', $target->id);

        $this->deleteJson("/api/v1/users/{$target->id}/block")->assertOk();
        $this->assertSame(0, $me->blockedUsers()->count());
    }

    public function test_you_cannot_block_yourself(): void
    {
        $me = User::factory()->create();
        Sanctum::actingAs($me);

        $this->postJson("/api/v1/users/{$me->id}/block")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('user');
    }

    public function test_a_blocked_users_profile_and_listings_404(): void
    {
        $me = User::factory()->create();
        $blocked = User::factory()->create();
        $listing = Listing::factory()->create(['user_id' => $blocked->id]);
        Sanctum::actingAs($me);
        $this->postJson("/api/v1/users/{$blocked->id}/block")->assertOk();

        $this->getJson("/api/v1/users/{$blocked->id}")->assertNotFound();
        $this->getJson("/api/v1/users/{$blocked->id}/listings")->assertNotFound();
        $this->getJson("/api/v1/listings/{$listing->id}")->assertNotFound();
    }

    public function test_a_blocked_user_cannot_make_a_swap_offer_or_message(): void
    {
        $owner = User::factory()->create();
        $requester = User::factory()->create();
        $listing = Listing::factory()->create(['user_id' => $owner->id]);

        Sanctum::actingAs($owner);
        $this->postJson("/api/v1/users/{$requester->id}/block")->assertOk();

        Sanctum::actingAs($requester);
        $this->postJson("/api/v1/listings/{$listing->id}/swap-offers", [])->assertForbidden();

        // An offer that already existed can no longer be messaged on.
        $offer = SwapOffer::factory()->create(['listing_id' => $listing->id, 'requester_id' => $requester->id]);
        $this->postJson("/api/v1/swap-offers/{$offer->id}/messages", ['body' => 'hello?'])->assertForbidden();

        // ...and it drops out of both parties' inboxes.
        $this->assertCount(0, $this->getJson('/api/v1/swap-offers')->json('data'));
        Sanctum::actingAs($owner);
        $this->assertCount(0, $this->getJson('/api/v1/swap-offers')->json('data'));
    }

    public function test_a_blocked_users_group_messages_are_hidden(): void
    {
        $me = User::factory()->create();
        $blocked = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $me->id]);
        $group->members()->attach($me->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now(), 'last_read_message_id' => 0]);
        $group->members()->attach($blocked->id, ['role' => GroupMemberRole::Member, 'joined_at' => now(), 'last_read_message_id' => 0]);
        $visible = GroupMessage::factory()->create(['group_id' => $group->id, 'sender_id' => $me->id]);
        $hidden = GroupMessage::factory()->create(['group_id' => $group->id, 'sender_id' => $blocked->id]);

        Sanctum::actingAs($me);
        $this->postJson("/api/v1/users/{$blocked->id}/block")->assertOk();

        $ids = collect($this->getJson("/api/v1/groups/{$group->id}/messages")->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($ids->contains($visible->id));
        $this->assertFalse($ids->contains($hidden->id));
    }

    public function test_a_report_describes_and_attributes_its_target(): void
    {
        $report = new Report;
        $report->reporter_id = User::factory()->create()->id;
        $report->target_type = \App\Enums\ReportTargetType::Post;
        $report->target_id = Post::factory()->create()->id;
        $report->reason = 'spam';
        $report->status = ReportStatus::Pending;
        $report->save();

        $this->assertNotSame('(deleted)', $report->fresh()->targetSummary());
        $this->assertNotNull($report->fresh()->targetOwner());
    }
}
