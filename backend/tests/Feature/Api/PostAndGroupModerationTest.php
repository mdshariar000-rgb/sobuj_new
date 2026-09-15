<?php

namespace Tests\Feature\Api;

use App\Enums\GroupMemberRole;
use App\Models\Group;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class PostAndGroupModerationTest extends TestCase
{
    use RefreshDatabase;

    // --- Post moderation (site-wide, distinct from group approval) --------

    public function test_a_deactivated_home_feed_post_is_hidden_from_the_feed(): void
    {
        $post = Post::factory()->create(['group_id' => null]);
        $post->moderation_status = 'deactivated';
        $post->save();

        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/feed');

        $response->assertOk();
        $response->assertJsonMissing(['id' => $post->id]);
    }

    public function test_a_banned_post_is_hidden_even_from_its_own_author(): void
    {
        $author = User::factory()->create();
        $post = Post::factory()->create(['group_id' => null, 'author_id' => $author->id]);
        $post->moderation_status = 'banned';
        $post->save();

        Sanctum::actingAs($author);

        $this->getJson("/api/v1/posts/{$post->id}")->assertForbidden();
    }

    public function test_a_deactivated_group_post_is_hidden_even_from_the_groups_own_admin(): void
    {
        $admin = User::factory()->create();
        $group = Group::factory()->create(['created_by' => $admin->id]);
        $group->members()->attach($admin->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()]);

        $post = Post::factory()->create(['group_id' => $group->id]);
        $post->moderation_status = 'deactivated';
        $post->save();

        Sanctum::actingAs($admin);

        $response = $this->getJson("/api/v1/groups/{$group->id}/posts");
        $response->assertOk();
        $response->assertJsonMissing(['id' => $post->id]);
    }

    // --- Group moderation ---------------------------------------------------

    public function test_a_deactivated_group_is_excluded_from_the_index(): void
    {
        $active = Group::factory()->create();
        $deactivated = Group::factory()->create();
        $deactivated->status = 'deactivated';
        $deactivated->save();

        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/groups');

        $response->assertOk();
        $response->assertJsonFragment(['id' => $active->id]);
        $response->assertJsonMissing(['id' => $deactivated->id]);
    }

    public function test_a_banned_group_blocks_show_and_join_for_everyone(): void
    {
        $group = Group::factory()->create();
        $group->status = 'banned';
        $group->save();

        Sanctum::actingAs(User::factory()->create());

        $this->getJson("/api/v1/groups/{$group->id}")->assertForbidden();
        $this->postJson("/api/v1/groups/{$group->id}/join")->assertForbidden();
    }

    public function test_a_deactivated_group_blocks_its_own_existing_members_from_chat(): void
    {
        $member = User::factory()->create();
        $group = Group::factory()->create();
        $group->members()->attach($member->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
        $group->status = 'deactivated';
        $group->save();

        Sanctum::actingAs($member);

        $this->getJson("/api/v1/groups/{$group->id}/messages")->assertForbidden();
    }

    public function test_a_verified_groups_api_resource_reports_verified_true(): void
    {
        $group = Group::factory()->create();
        $group->verified_at = now();
        $group->save();

        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson("/api/v1/groups/{$group->id}");

        $response->assertOk();
        $response->assertJsonPath('data.verified', true);
    }

    public function test_an_unverified_groups_api_resource_reports_verified_false(): void
    {
        $group = Group::factory()->create();

        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson("/api/v1/groups/{$group->id}");

        $response->assertOk();
        $response->assertJsonPath('data.verified', false);
    }

    // --- User suspension --------------------------------------------------

    public function test_a_temporarily_banned_user_is_blocked_until_the_ban_expires(): void
    {
        $user = User::factory()->create([
            'is_suspended' => true,
            'suspended_until' => now()->addDay(),
        ]);
        Sanctum::actingAs($user);

        $this->getJson('/api/v1/groups')->assertForbidden();
    }

    public function test_an_expired_temporary_ban_no_longer_blocks_access(): void
    {
        $user = User::factory()->create([
            'is_suspended' => true,
            'suspended_until' => now()->subDay(),
        ]);
        Sanctum::actingAs($user);

        $this->getJson('/api/v1/groups')->assertOk();
    }

    public function test_a_permanently_banned_user_is_always_blocked(): void
    {
        $user = User::factory()->create([
            'is_suspended' => true,
            'suspended_until' => null,
        ]);
        Sanctum::actingAs($user);

        $this->getJson('/api/v1/groups')->assertForbidden();
    }
}
