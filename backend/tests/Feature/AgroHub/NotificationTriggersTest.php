<?php

namespace Tests\Feature\AgroHub;

use App\Enums\GroupMemberRole;
use App\Enums\ListingStatus;
use App\Enums\NotificationType;
use App\Models\DeviceToken;
use App\Models\Group;
use App\Models\Listing;
use App\Models\Post;
use App\Models\User;
use App\Services\Push\PushSender;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Every notification trigger point, verified end-to-end through the real
 * API routes — mocking only PushSender (never real Firebase), same
 * precedent as StripePriceService being mocked in ManageSettingsTest.
 */
class NotificationTriggersTest extends TestCase
{
    use RefreshDatabase;

    // --- Post liked -------------------------------------------------------

    public function test_liking_someone_elses_post_notifies_the_author_and_pushes_to_their_devices(): void
    {
        $author = User::factory()->create();
        $post = Post::factory()->create(['author_id' => $author->id, 'group_id' => null]);
        DeviceToken::factory()->create(['user_id' => $author->id, 'token' => 'author-token']);

        $liker = User::factory()->create();
        Sanctum::actingAs($liker);

        $this->mock(PushSender::class, function ($mock) {
            $mock->shouldReceive('sendToTokens')
                ->once()
                ->with(['author-token'], \Mockery::type('string'), \Mockery::type('string'), \Mockery::type('array'))
                ->andReturn([]);
        });

        $this->postJson("/api/v1/posts/{$post->id}/like")->assertOk();

        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $author->id,
            'actor_id' => $liker->id,
            'type' => NotificationType::PostLiked->value,
        ]);
    }

    public function test_liking_your_own_post_does_not_self_notify(): void
    {
        $author = User::factory()->create();
        $post = Post::factory()->create(['author_id' => $author->id, 'group_id' => null]);
        Sanctum::actingAs($author);

        $this->mock(PushSender::class, function ($mock) {
            $mock->shouldNotReceive('sendToTokens');
        });

        $this->postJson("/api/v1/posts/{$post->id}/like")->assertOk();

        $this->assertDatabaseCount('app_notifications', 0);
    }

    public function test_reliking_an_already_liked_post_does_not_notify_again(): void
    {
        $author = User::factory()->create();
        $post = Post::factory()->create(['author_id' => $author->id, 'group_id' => null]);
        $liker = User::factory()->create();
        Sanctum::actingAs($liker);

        $this->postJson("/api/v1/posts/{$post->id}/like")->assertOk();
        $this->postJson("/api/v1/posts/{$post->id}/like")->assertOk();

        $this->assertDatabaseCount('app_notifications', 1);
    }

    // --- Post commented -----------------------------------------------------

    public function test_commenting_on_someone_elses_post_notifies_the_author(): void
    {
        $author = User::factory()->create();
        $post = Post::factory()->create(['author_id' => $author->id, 'group_id' => null]);

        $commenter = User::factory()->create();
        Sanctum::actingAs($commenter);

        $this->postJson("/api/v1/posts/{$post->id}/comments", ['body' => 'Great tomatoes!'])->assertCreated();

        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $author->id,
            'actor_id' => $commenter->id,
            'type' => NotificationType::PostCommented->value,
        ]);
    }

    public function test_commenting_on_your_own_post_does_not_self_notify(): void
    {
        $author = User::factory()->create();
        $post = Post::factory()->create(['author_id' => $author->id, 'group_id' => null]);
        Sanctum::actingAs($author);

        $this->postJson("/api/v1/posts/{$post->id}/comments", ['body' => 'My own thoughts'])->assertCreated();

        $this->assertDatabaseCount('app_notifications', 0);
    }

    // --- Comment replied-to (dual notification) ------------------------------

    public function test_replying_to_a_comment_notifies_both_the_post_author_and_the_parent_comments_author(): void
    {
        $postAuthor = User::factory()->create();
        $post = Post::factory()->create(['author_id' => $postAuthor->id, 'group_id' => null]);

        $originalCommenter = User::factory()->create();
        Sanctum::actingAs($originalCommenter);
        $original = $this->postJson("/api/v1/posts/{$post->id}/comments", ['body' => 'First!'])
            ->json('data.id');

        $replier = User::factory()->create();
        Sanctum::actingAs($replier);
        $this->postJson("/api/v1/posts/{$post->id}/comments", [
            'body' => 'I disagree',
            'reply_to_comment_id' => $original,
        ])->assertCreated();

        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $postAuthor->id,
            'actor_id' => $replier->id,
            'type' => NotificationType::PostCommented->value,
        ]);
        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $originalCommenter->id,
            'actor_id' => $replier->id,
            'type' => NotificationType::CommentReplied->value,
        ]);
        // The first top-level comment already notified postAuthor once
        // (post_commented); the reply then adds a second post_commented row
        // (postAuthor, from the reply) plus one comment_replied row
        // (originalCommenter) = 3 total.
        $this->assertDatabaseCount('app_notifications', 3);
    }

    public function test_replying_when_the_parent_comments_author_is_the_post_author_creates_exactly_one_row(): void
    {
        $postAuthor = User::factory()->create();
        $post = Post::factory()->create(['author_id' => $postAuthor->id, 'group_id' => null]);

        Sanctum::actingAs($postAuthor);
        $original = $this->postJson("/api/v1/posts/{$post->id}/comments", ['body' => 'My own comment'])
            ->json('data.id');

        $replier = User::factory()->create();
        Sanctum::actingAs($replier);
        $this->postJson("/api/v1/posts/{$post->id}/comments", [
            'body' => 'Replying to the post author',
            'reply_to_comment_id' => $original,
        ])->assertCreated();

        // Only one row — CommentReplied would have duplicated PostCommented
        // since the parent comment's author IS the post author.
        $this->assertDatabaseCount('app_notifications', 1);
        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $postAuthor->id,
            'type' => NotificationType::PostCommented->value,
        ]);
    }

    public function test_replying_to_your_own_comment_does_not_self_notify_for_the_reply(): void
    {
        $postAuthor = User::factory()->create();
        $post = Post::factory()->create(['author_id' => $postAuthor->id, 'group_id' => null]);

        $commenter = User::factory()->create();
        Sanctum::actingAs($commenter);
        $original = $this->postJson("/api/v1/posts/{$post->id}/comments", ['body' => 'First!'])
            ->json('data.id');

        // Same user replies to their own comment.
        $this->postJson("/api/v1/posts/{$post->id}/comments", [
            'body' => 'Adding more context',
            'reply_to_comment_id' => $original,
        ])->assertCreated();

        // Two PostCommented rows (postAuthor, one per comment — the
        // original and the reply) — no CommentReplied row, since the
        // replier and the parent comment's author are the same person.
        $this->assertDatabaseCount('app_notifications', 2);
        $this->assertDatabaseMissing('app_notifications', [
            'type' => NotificationType::CommentReplied->value,
        ]);
    }

    // --- Swap-offer message -------------------------------------------------

    public function test_sending_a_swap_offer_message_notifies_the_other_party_not_the_sender(): void
    {
        $seller = User::factory()->create();
        $listing = Listing::factory()->create(['user_id' => $seller->id, 'status' => ListingStatus::Active]);
        $buyer = User::factory()->create();
        Sanctum::actingAs($buyer);
        $offerId = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers")->json('data.id');

        $this->postJson("/api/v1/swap-offers/{$offerId}/messages", ['body' => 'Is this still available?'])
            ->assertCreated();

        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $seller->id,
            'actor_id' => $buyer->id,
            'type' => NotificationType::SwapMessageReceived->value,
        ]);
        $this->assertDatabaseCount('app_notifications', 1);

        // The seller replies — the buyer (not the seller) gets notified this time.
        Sanctum::actingAs($seller);
        $this->postJson("/api/v1/swap-offers/{$offerId}/messages", ['body' => 'Yes it is!'])
            ->assertCreated();

        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $buyer->id,
            'actor_id' => $seller->id,
            'type' => NotificationType::SwapMessageReceived->value,
        ]);
    }

    // --- Group message --------------------------------------------------------

    public function test_a_group_message_notifies_every_other_member_not_the_sender(): void
    {
        $group = Group::factory()->create();
        $sender = User::factory()->create();
        $memberTwo = User::factory()->create();
        $memberThree = User::factory()->create();
        $group->members()->attach($sender->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);
        $group->members()->attach($memberTwo->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
        $group->members()->attach($memberThree->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);

        Sanctum::actingAs($sender);
        $this->postJson("/api/v1/groups/{$group->id}/messages", ['body' => 'Anyone free this weekend?'])
            ->assertCreated();

        $this->assertDatabaseCount('app_notifications', 2);
        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $memberTwo->id,
            'type' => NotificationType::GroupMessageReceived->value,
        ]);
        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $memberThree->id,
            'type' => NotificationType::GroupMessageReceived->value,
        ]);
        $this->assertDatabaseMissing('app_notifications', ['recipient_id' => $sender->id]);
    }

    public function test_an_invalid_device_token_reported_by_the_push_sender_is_pruned(): void
    {
        $author = User::factory()->create();
        $post = Post::factory()->create(['author_id' => $author->id, 'group_id' => null]);
        DeviceToken::factory()->create(['user_id' => $author->id, 'token' => 'dead-token']);

        $liker = User::factory()->create();
        Sanctum::actingAs($liker);

        $this->mock(PushSender::class, function ($mock) {
            $mock->shouldReceive('sendToTokens')->once()->andReturn(['dead-token']);
        });

        $this->postJson("/api/v1/posts/{$post->id}/like")->assertOk();

        $this->assertDatabaseMissing('device_tokens', ['token' => 'dead-token']);
    }
}
