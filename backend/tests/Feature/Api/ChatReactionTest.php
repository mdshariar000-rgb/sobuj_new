<?php

namespace Tests\Feature\Api;

use App\Enums\GroupMemberRole;
use App\Enums\ListingStatus;
use App\Events\GroupMessageReactionsUpdated;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\Listing;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ChatReactionTest extends TestCase
{
    use RefreshDatabase;

    private function groupWithMembers(User ...$users): Group
    {
        $group = Group::factory()->create();
        foreach ($users as $user) {
            $group->members()->attach($user->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
        }

        return $group;
    }

    private function groupMessage(Group $group, User $sender, string $body = 'Hello'): GroupMessage
    {
        $message = GroupMessage::factory()->create(['group_id' => $group->id, 'body' => $body]);
        $message->sender_id = $sender->id;
        $message->save();

        return $message;
    }

    public function test_members_react_and_the_summary_groups_by_emoji(): void
    {
        [$a, $b, $c] = User::factory()->count(3)->create()->all();
        $group = $this->groupWithMembers($a, $b, $c);
        $message = $this->groupMessage($group, $a);
        $url = "/api/v1/groups/{$group->id}/messages/{$message->id}/reaction";

        Sanctum::actingAs($b);
        $this->putJson($url, ['emoji' => '❤️'])->assertOk();
        Sanctum::actingAs($c);
        $response = $this->putJson($url, ['emoji' => '❤️'])->assertOk();

        $response->assertJsonPath('data.message_id', $message->id);
        $response->assertJsonPath('data.reactions.0.emoji', '❤️');
        $response->assertJsonPath('data.reactions.0.count', 2);
        $this->assertEqualsCanonicalizing([$b->id, $c->id], $response->json('data.reactions.0.user_ids'));

        // The chat listing carries the same summary.
        $this->getJson("/api/v1/groups/{$group->id}/messages")
            ->assertJsonPath('data.0.reactions.0.count', 2);
    }

    public function test_reacting_again_replaces_and_delete_removes(): void
    {
        [$a, $b] = User::factory()->count(2)->create()->all();
        $group = $this->groupWithMembers($a, $b);
        $message = $this->groupMessage($group, $a);
        $url = "/api/v1/groups/{$group->id}/messages/{$message->id}/reaction";
        Sanctum::actingAs($b);

        $this->putJson($url, ['emoji' => '👍']);
        $this->putJson($url, ['emoji' => '😂'])
            ->assertJsonCount(1, 'data.reactions')
            ->assertJsonPath('data.reactions.0.emoji', '😂');
        $this->assertDatabaseCount('group_message_reactions', 1);

        $this->deleteJson($url)->assertOk()->assertJsonPath('data.reactions', []);
        $this->assertDatabaseCount('group_message_reactions', 0);
    }

    public function test_only_the_offered_emoji_are_accepted(): void
    {
        [$a, $b] = User::factory()->count(2)->create()->all();
        $group = $this->groupWithMembers($a, $b);
        $message = $this->groupMessage($group, $a);
        Sanctum::actingAs($b);

        $this->putJson("/api/v1/groups/{$group->id}/messages/{$message->id}/reaction", ['emoji' => '💩'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['emoji']);
    }

    public function test_non_members_and_other_groups_messages_are_refused(): void
    {
        [$a, $outsider] = User::factory()->count(2)->create()->all();
        $group = $this->groupWithMembers($a);
        $message = $this->groupMessage($group, $a);

        Sanctum::actingAs($outsider);
        $this->putJson("/api/v1/groups/{$group->id}/messages/{$message->id}/reaction", ['emoji' => '👍'])
            ->assertForbidden();

        $otherGroup = $this->groupWithMembers($outsider);
        $this->putJson("/api/v1/groups/{$otherGroup->id}/messages/{$message->id}/reaction", ['emoji' => '👍'])
            ->assertNotFound();
    }

    public function test_a_reaction_is_broadcast_to_the_group(): void
    {
        Event::fake([GroupMessageReactionsUpdated::class]);
        [$a, $b] = User::factory()->count(2)->create()->all();
        $group = $this->groupWithMembers($a, $b);
        $message = $this->groupMessage($group, $a);
        Sanctum::actingAs($b);

        $this->putJson("/api/v1/groups/{$group->id}/messages/{$message->id}/reaction", ['emoji' => '🙏']);

        Event::assertDispatched(
            GroupMessageReactionsUpdated::class,
            fn ($event) => $event->message->id === $message->id
                && $event->broadcastWith()['reactions'][0]['emoji'] === '🙏',
        );
    }

    public function test_reactions_from_blocked_users_are_hidden_in_the_listing(): void
    {
        [$viewer, $blocked, $author] = User::factory()->count(3)->create()->all();
        $group = $this->groupWithMembers($viewer, $blocked, $author);
        $message = $this->groupMessage($group, $author);
        $message->reactions()->create(['user_id' => $blocked->id, 'emoji' => '😂']);
        DB::table('user_blocks')->insert(['blocker_id' => $viewer->id, 'blocked_id' => $blocked->id, 'created_at' => now()]);

        Sanctum::actingAs($viewer);
        $this->getJson("/api/v1/groups/{$group->id}/messages")
            ->assertJsonPath('data.0.reactions', []);
    }

    public function test_both_parties_can_react_in_a_swap_offer_thread(): void
    {
        $seller = User::factory()->create();
        $listing = Listing::factory()->create(['user_id' => $seller->id, 'status' => ListingStatus::Active]);
        $buyer = User::factory()->create();
        Sanctum::actingAs($buyer);
        $offerId = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers")->json('data.id');
        $messageId = $this->postJson("/api/v1/swap-offers/{$offerId}/messages", ['body' => 'Hi'])->json('data.id');

        Sanctum::actingAs($seller);
        $this->putJson("/api/v1/swap-offers/{$offerId}/messages/{$messageId}/reaction", ['emoji' => '👍'])
            ->assertOk()
            ->assertJsonPath('data.reactions.0.user_ids', [$seller->id]);

        Sanctum::actingAs(User::factory()->create());
        $this->putJson("/api/v1/swap-offers/{$offerId}/messages/{$messageId}/reaction", ['emoji' => '👍'])
            ->assertForbidden();
    }
}
