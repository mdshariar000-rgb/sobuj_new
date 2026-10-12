<?php

namespace Tests\Feature\Api;

use App\Enums\GroupMemberRole;
use App\Models\Group;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class GroupPrivacyAndModerationTest extends TestCase
{
    use RefreshDatabase;

    // --- Group visibility -------------------------------------------------

    public function test_a_group_can_be_created_private_and_defaults_to_public(): void
    {
        Sanctum::actingAs(User::factory()->create(['is_admin' => true]));

        $private = $this->postJson('/api/v1/groups', [
            'name' => 'Secret Seed Bank',
            'slug' => 'secret-seed-bank',
            'visibility' => 'private',
        ]);
        $private->assertCreated();
        $private->assertJsonPath('data.visibility', 'private');

        $default = $this->postJson('/api/v1/groups', [
            'name' => 'Open Garden Club',
            'slug' => 'open-garden-club',
        ]);
        $default->assertCreated();
        $default->assertJsonPath('data.visibility', 'public');
    }

    public function test_joining_a_public_group_is_still_instant(): void
    {
        $group = Group::factory()->create(['visibility' => 'public']);
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson("/api/v1/groups/{$group->id}/join");

        $response->assertOk();
        $response->assertJsonPath('data.is_member', true);
        $this->assertDatabaseHas('group_members', ['group_id' => $group->id, 'user_id' => $user->id]);
        $this->assertDatabaseMissing('group_join_requests', ['group_id' => $group->id, 'user_id' => $user->id]);
    }

    public function test_joining_a_private_group_files_a_request_instead_of_joining(): void
    {
        $group = Group::factory()->private()->create();
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $response = $this->postJson("/api/v1/groups/{$group->id}/join");

        $response->assertStatus(202);
        $this->assertDatabaseHas('group_join_requests', [
            'group_id' => $group->id,
            'user_id' => $user->id,
            'status' => 'pending',
        ]);
        $this->assertDatabaseMissing('group_members', ['group_id' => $group->id, 'user_id' => $user->id]);

        // Still not a real member — can't reach the group's chat or post
        // into it while the request is pending.
        $this->getJson("/api/v1/groups/{$group->id}/messages")->assertForbidden();
        $this->postJson('/api/v1/posts', ['group_id' => $group->id, 'body' => 'Hello'])
            ->assertUnprocessable();
    }

    public function test_requesting_the_same_private_group_twice_while_pending_is_rejected(): void
    {
        $group = Group::factory()->private()->create();
        Sanctum::actingAs(User::factory()->create());

        $this->postJson("/api/v1/groups/{$group->id}/join")->assertStatus(202);
        $this->postJson("/api/v1/groups/{$group->id}/join")->assertUnprocessable();
    }

    public function test_a_user_can_cancel_their_own_pending_join_request(): void
    {
        $group = Group::factory()->private()->create();
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson("/api/v1/groups/{$group->id}/join")->assertStatus(202);

        $this->deleteJson("/api/v1/groups/{$group->id}/join-requests/me")->assertOk();
        $this->assertDatabaseMissing('group_join_requests', ['group_id' => $group->id, 'user_id' => $user->id]);

        // Free to request again immediately.
        $this->postJson("/api/v1/groups/{$group->id}/join")->assertStatus(202);
    }

    // --- Join request moderation -------------------------------------------

    public function test_a_non_admin_cannot_approve_or_reject_join_requests(): void
    {
        $group = Group::factory()->private()->create();
        $requester = User::factory()->create();
        Sanctum::actingAs($requester);
        $this->postJson("/api/v1/groups/{$group->id}/join")->assertStatus(202);
        $joinRequestId = $group->joinRequests()->first()->id;

        $outsider = User::factory()->create();
        Sanctum::actingAs($outsider);

        $this->getJson("/api/v1/groups/{$group->id}/join-requests")->assertForbidden();
        $this->patchJson("/api/v1/groups/{$group->id}/join-requests/{$joinRequestId}", ['decision' => 'approve'])
            ->assertForbidden();
    }

    public function test_the_group_admin_can_approve_a_join_request(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->private()->create(['created_by' => $admin->id]);
        $group->members()->attach($admin->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);

        $requester = User::factory()->create();
        Sanctum::actingAs($requester);
        $this->postJson("/api/v1/groups/{$group->id}/join")->assertStatus(202);
        $joinRequest = $group->joinRequests()->first();

        Sanctum::actingAs($admin);
        $list = $this->getJson("/api/v1/groups/{$group->id}/join-requests");
        $list->assertOk();
        $list->assertJsonCount(1, 'data');
        $list->assertJsonPath('data.0.user.id', $requester->id);

        $decision = $this->patchJson(
            "/api/v1/groups/{$group->id}/join-requests/{$joinRequest->id}",
            ['decision' => 'approve'],
        );
        $decision->assertOk();

        $this->assertDatabaseHas('group_members', ['group_id' => $group->id, 'user_id' => $requester->id]);
        $this->assertDatabaseMissing('group_join_requests', ['id' => $joinRequest->id]);
    }

    public function test_the_group_admin_can_reject_a_join_request_and_the_user_can_re_request(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->private()->create(['created_by' => $admin->id]);
        $group->members()->attach($admin->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);

        $requester = User::factory()->create();
        Sanctum::actingAs($requester);
        $this->postJson("/api/v1/groups/{$group->id}/join")->assertStatus(202);
        $joinRequest = $group->joinRequests()->first();

        Sanctum::actingAs($admin);
        $this->patchJson(
            "/api/v1/groups/{$group->id}/join-requests/{$joinRequest->id}",
            ['decision' => 'reject'],
        )->assertOk();

        $this->assertDatabaseHas('group_join_requests', [
            'id' => $joinRequest->id,
            'status' => 'rejected',
            'decided_by' => $admin->id,
        ]);
        $this->assertDatabaseMissing('group_members', ['group_id' => $group->id, 'user_id' => $requester->id]);

        Sanctum::actingAs($requester);
        $this->postJson("/api/v1/groups/{$group->id}/join")->assertStatus(202);
        $this->assertDatabaseHas('group_join_requests', [
            'group_id' => $group->id,
            'user_id' => $requester->id,
            'status' => 'pending',
        ]);
    }

    public function test_switching_a_private_group_to_public_auto_approves_pending_requests(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->private()->create(['created_by' => $admin->id]);
        $group->members()->attach($admin->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);

        $requester = User::factory()->create();
        Sanctum::actingAs($requester);
        $this->postJson("/api/v1/groups/{$group->id}/join")->assertStatus(202);

        Sanctum::actingAs($admin);
        $this->patchJson("/api/v1/groups/{$group->id}", ['visibility' => 'public'])->assertOk();

        $this->assertDatabaseHas('group_members', ['group_id' => $group->id, 'user_id' => $requester->id]);
        $this->assertDatabaseMissing('group_join_requests', ['group_id' => $group->id, 'user_id' => $requester->id]);
    }

    // --- Post moderation ----------------------------------------------------

    public function test_posting_into_a_private_group_as_a_non_admin_starts_pending(): void
    {
        $group = Group::factory()->private()->create();
        $member = User::factory()->create();
        $group->members()->attach($member->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
        Sanctum::actingAs($member);

        $response = $this->postJson('/api/v1/posts', ['group_id' => $group->id, 'body' => 'Aphids on my basil']);

        $response->assertCreated();
        $response->assertJsonPath('data.approval_status', 'pending');
    }

    public function test_posting_into_a_private_group_as_its_admin_is_approved_immediately(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->private()->create(['created_by' => $admin->id]);
        $group->members()->attach($admin->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);
        Sanctum::actingAs($admin);

        $response = $this->postJson('/api/v1/posts', ['group_id' => $group->id, 'body' => 'Welcome everyone']);

        $response->assertCreated();
        $response->assertJsonPath('data.approval_status', 'approved');
    }

    public function test_posting_into_a_public_group_is_always_approved(): void
    {
        $group = Group::factory()->create(['visibility' => 'public']);
        $member = User::factory()->create();
        $group->members()->attach($member->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
        Sanctum::actingAs($member);

        $response = $this->postJson('/api/v1/posts', ['group_id' => $group->id, 'body' => 'Hello group']);

        $response->assertCreated();
        $response->assertJsonPath('data.approval_status', 'approved');
    }

    public function test_a_pending_post_is_hidden_from_other_members_but_visible_to_its_author_and_admins(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->private()->create(['created_by' => $admin->id]);
        $group->members()->attach($admin->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);

        $author = User::factory()->create();
        $group->members()->attach($author->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);

        $otherMember = User::factory()->create();
        $group->members()->attach($otherMember->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);

        Sanctum::actingAs($author);
        $created = $this->postJson('/api/v1/posts', ['group_id' => $group->id, 'body' => 'Pending post']);
        $postId = $created->json('data.id');

        Sanctum::actingAs($otherMember);
        $asOther = $this->getJson("/api/v1/groups/{$group->id}/posts");
        $asOther->assertOk();
        $asOther->assertJsonCount(0, 'data');
        $this->getJson("/api/v1/posts/{$postId}")->assertForbidden();
        $this->getJson("/api/v1/posts/{$postId}/comments")->assertForbidden();

        Sanctum::actingAs($author);
        $asAuthor = $this->getJson("/api/v1/groups/{$group->id}/posts");
        $asAuthor->assertJsonCount(1, 'data');
        $this->getJson("/api/v1/posts/{$postId}")->assertOk();

        Sanctum::actingAs($admin);
        $asAdmin = $this->getJson("/api/v1/groups/{$group->id}/posts");
        $asAdmin->assertJsonCount(1, 'data');
        $this->getJson("/api/v1/posts/{$postId}")->assertOk();
    }

    public function test_only_a_group_admin_can_approve_or_reject_a_pending_post(): void
    {
        $group = Group::factory()->private()->create();
        $author = User::factory()->create();
        $group->members()->attach($author->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
        Sanctum::actingAs($author);
        $post = new Post(['group_id' => $group->id, 'body' => 'Pending post']);
        $post->author_id = $author->id;
        // approval_status isn't mass-assignable (only ever set by
        // PostController — see Post::$fillable), so set it directly here.
        $post->approval_status = 'pending';
        $post->save();

        $outsider = User::factory()->create();
        Sanctum::actingAs($outsider);
        $this->postJson("/api/v1/posts/{$post->id}/approve")->assertForbidden();
    }

    public function test_the_group_admin_can_approve_and_reject_a_pending_post(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->private()->create(['created_by' => $admin->id]);
        $group->members()->attach($admin->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);

        $author = User::factory()->create();
        $group->members()->attach($author->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
        Sanctum::actingAs($author);
        $created = $this->postJson('/api/v1/posts', ['group_id' => $group->id, 'body' => 'Pending post']);
        $postId = $created->json('data.id');

        Sanctum::actingAs($admin);
        $this->postJson("/api/v1/posts/{$postId}/approve")->assertOk();
        $this->assertDatabaseHas('posts', ['id' => $postId, 'approval_status' => 'approved']);

        $otherMember = User::factory()->create();
        $group->members()->attach($otherMember->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
        Sanctum::actingAs($otherMember);
        $this->getJson("/api/v1/groups/{$group->id}/posts")->assertJsonCount(1, 'data');

        Sanctum::actingAs($admin);
        $this->postJson("/api/v1/posts/{$postId}/reject")->assertOk();
        $this->assertDatabaseHas('posts', ['id' => $postId, 'approval_status' => 'rejected']);

        Sanctum::actingAs($otherMember);
        $this->getJson("/api/v1/groups/{$group->id}/posts")->assertJsonCount(0, 'data');
    }
}
