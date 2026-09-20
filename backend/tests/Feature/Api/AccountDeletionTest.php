<?php

namespace Tests\Feature\Api;

use App\Enums\GroupMemberRole;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\Listing;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AccountDeletionTest extends TestCase
{
    use RefreshDatabase;

    public function test_deleting_requires_the_correct_password(): void
    {
        $user = User::factory()->create(['password' => 'correct-horse-9']);
        Sanctum::actingAs($user);

        $this->deleteJson('/api/v1/auth/me', [])->assertUnprocessable()->assertJsonValidationErrors('password');
        $this->deleteJson('/api/v1/auth/me', ['password' => 'wrong'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('password');

        $this->assertDatabaseHas('users', ['id' => $user->id]);
    }

    public function test_deleting_removes_the_account_its_content_and_files(): void
    {
        Storage::fake('public');
        Storage::disk('public')->put('avatars/me.jpg', 'x');
        Storage::disk('public')->put('posts/mine.jpg', 'x');

        $user = User::factory()->create(['password' => 'correct-horse-9', 'avatar_path' => 'avatars/me.jpg']);
        $post = Post::factory()->create(['author_id' => $user->id, 'image_path' => 'posts/mine.jpg']);
        $listing = Listing::factory()->create(['user_id' => $user->id]);
        $token = $user->createToken('t');

        Sanctum::actingAs($user);
        $this->deleteJson('/api/v1/auth/me', ['password' => 'correct-horse-9'])
            ->assertOk()
            ->assertJsonPath('message', 'Your account has been deleted.');

        $this->assertDatabaseMissing('users', ['id' => $user->id]);
        $this->assertDatabaseMissing('posts', ['id' => $post->id]);
        $this->assertDatabaseMissing('listings', ['id' => $listing->id]);
        $this->assertDatabaseMissing('personal_access_tokens', ['id' => $token->accessToken->id]);
        Storage::disk('public')->assertMissing('avatars/me.jpg');
        Storage::disk('public')->assertMissing('posts/mine.jpg');
    }

    public function test_a_suspended_user_can_still_delete_their_account(): void
    {
        $user = User::factory()->create(['password' => 'correct-horse-9', 'is_suspended' => true]);
        Sanctum::actingAs($user);

        $this->deleteJson('/api/v1/auth/me', ['password' => 'correct-horse-9'])->assertOk();
        $this->assertDatabaseMissing('users', ['id' => $user->id]);
    }

    public function test_a_group_with_other_members_is_handed_over_not_deleted(): void
    {
        $creator = User::factory()->create(['password' => 'correct-horse-9']);
        $member = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $creator->id]);
        $group->members()->attach($creator->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now(), 'last_read_message_id' => 0]);
        $group->members()->attach($member->id, ['role' => GroupMemberRole::Member, 'joined_at' => now(), 'last_read_message_id' => 0]);

        Sanctum::actingAs($creator);
        $this->deleteJson('/api/v1/auth/me', ['password' => 'correct-horse-9'])->assertOk();

        $this->assertDatabaseHas('groups', ['id' => $group->id, 'created_by' => $member->id]);
        $this->assertDatabaseHas('group_members', [
            'group_id' => $group->id, 'user_id' => $member->id, 'role' => 'admin',
        ]);
    }

    public function test_a_group_with_no_other_members_is_deleted_with_its_creator(): void
    {
        $creator = User::factory()->create(['password' => 'correct-horse-9']);
        $group = Group::factory()->create(['created_by' => $creator->id]);
        $group->members()->attach($creator->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now(), 'last_read_message_id' => 0]);

        Sanctum::actingAs($creator);
        $this->deleteJson('/api/v1/auth/me', ['password' => 'correct-horse-9'])->assertOk();

        $this->assertDatabaseMissing('groups', ['id' => $group->id]);
    }

    public function test_their_chat_messages_are_removed_but_other_members_messages_stay(): void
    {
        $leaver = User::factory()->create(['password' => 'correct-horse-9']);
        $stayer = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $stayer->id]);
        $mine = GroupMessage::factory()->create(['group_id' => $group->id, 'sender_id' => $leaver->id]);
        $theirs = GroupMessage::factory()->create(['group_id' => $group->id, 'sender_id' => $stayer->id]);

        Sanctum::actingAs($leaver);
        $this->deleteJson('/api/v1/auth/me', ['password' => 'correct-horse-9'])->assertOk();

        $this->assertDatabaseMissing('group_messages', ['id' => $mine->id]);
        $this->assertDatabaseHas('group_messages', ['id' => $theirs->id]);
    }

    public function test_unauthenticated_delete_is_rejected(): void
    {
        $this->deleteJson('/api/v1/auth/me', ['password' => 'x'])->assertUnauthorized();
    }
}
