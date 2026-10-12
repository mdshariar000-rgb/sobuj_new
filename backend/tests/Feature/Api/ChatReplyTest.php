<?php

namespace Tests\Feature\Api;

use App\Enums\GroupMemberRole;
use App\Enums\ListingStatus;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\Listing;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ChatReplyTest extends TestCase
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

    public function test_a_swap_message_can_reply_to_an_earlier_one_in_the_thread(): void
    {
        Storage::fake('public');
        $listing = Listing::factory()->create(['status' => ListingStatus::Active]);
        $buyer = User::factory()->create(['name' => 'Rina']);
        Sanctum::actingAs($buyer);
        $offerId = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers")->json('data.id');

        $originalId = $this->post("/api/v1/swap-offers/{$offerId}/messages", [
            'body' => 'Is this still available?',
            'images' => [UploadedFile::fake()->image('a.jpg'), UploadedFile::fake()->image('b.jpg')],
        ])->json('data.id');

        // Multipart, like the app sends it — form fields arrive as strings,
        // and reply_to_id must still come back as an integer.
        $response = $this->post("/api/v1/swap-offers/{$offerId}/messages", [
            'body' => 'Asking again',
            'reply_to_id' => (string) $originalId,
        ], ['Accept' => 'application/json']);

        $response->assertCreated();
        $this->assertSame($originalId, $response->json('data.reply_to_id'));
        $response->assertJsonPath('data.reply_to.id', $originalId);
        $response->assertJsonPath('data.reply_to.body', 'Is this still available?');
        $response->assertJsonPath('data.reply_to.sender_name', 'Rina');
        $response->assertJsonPath('data.reply_to.image_count', 2);

        // The thread listing carries the same quote.
        $this->getJson("/api/v1/swap-offers/{$offerId}/messages")
            ->assertJsonPath('data.1.reply_to.id', $originalId);
    }

    public function test_a_message_that_is_not_a_reply_has_no_quote(): void
    {
        $member = User::factory()->create();
        $group = $this->groupWithMembers($member);
        Sanctum::actingAs($member);

        $this->postJson("/api/v1/groups/{$group->id}/messages", ['body' => 'Hi'])
            ->assertCreated()
            ->assertJsonPath('data.reply_to_id', null)
            ->assertJsonPath('data.reply_to', null);
    }

    public function test_a_reply_cannot_quote_a_message_from_another_chat(): void
    {
        $member = User::factory()->create();
        $group = $this->groupWithMembers($member);
        $otherGroupMessage = GroupMessage::factory()->create(['group_id' => Group::factory()->create()->id]);
        Sanctum::actingAs($member);

        $this->postJson("/api/v1/groups/{$group->id}/messages", [
            'body' => 'Sneaky',
            'reply_to_id' => $otherGroupMessage->id,
        ])->assertUnprocessable()->assertJsonValidationErrors(['reply_to_id']);
    }

    public function test_a_reply_to_a_deleted_message_shows_the_quote_as_unavailable(): void
    {
        $member = User::factory()->create();
        $group = $this->groupWithMembers($member);
        Sanctum::actingAs($member);

        $originalId = $this->postJson("/api/v1/groups/{$group->id}/messages", ['body' => 'Original'])->json('data.id');
        $this->postJson("/api/v1/groups/{$group->id}/messages", ['body' => 'Reply', 'reply_to_id' => $originalId]);
        GroupMessage::whereKey($originalId)->delete();

        $this->getJson("/api/v1/groups/{$group->id}/messages")
            ->assertJsonPath('data.0.body', 'Reply')
            ->assertJsonPath('data.0.reply_to_id', $originalId)
            ->assertJsonPath('data.0.reply_to', null);
    }

    public function test_a_quote_of_a_blocked_users_message_is_withheld(): void
    {
        $viewer = User::factory()->create();
        $blocked = User::factory()->create();
        $replier = User::factory()->create();
        $group = $this->groupWithMembers($viewer, $blocked, $replier);

        $original = GroupMessage::factory()->create(['group_id' => $group->id, 'body' => 'From blocked']);
        $original->sender_id = $blocked->id;
        $original->save();
        $reply = GroupMessage::factory()->create(['group_id' => $group->id, 'body' => 'Replying', 'reply_to_id' => $original->id]);
        $reply->sender_id = $replier->id;
        $reply->save();

        DB::table('user_blocks')->insert(['blocker_id' => $viewer->id, 'blocked_id' => $blocked->id, 'created_at' => now()]);
        Sanctum::actingAs($viewer);

        $this->getJson("/api/v1/groups/{$group->id}/messages")
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.body', 'Replying')
            ->assertJsonPath('data.0.reply_to', null);
    }
}
