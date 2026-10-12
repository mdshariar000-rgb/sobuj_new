<?php

namespace Tests\Feature\AgroHub;

use App\Enums\GroupMemberRole;
use App\Models\Comment;
use App\Models\Group;
use App\Models\Post;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class GroupsAndPostsTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_can_join_a_group_and_appears_in_its_members(): void
    {
        $group = Group::factory()->create();
        $user = User::factory()->create();

        $group->members()->attach($user->id, [
            'role' => GroupMemberRole::Member,
            'joined_at' => now(),
        ]);

        $this->assertTrue($group->fresh()->members->contains($user));
        $this->assertTrue($user->fresh()->groups->contains($group));

        $pivot = $group->members()->first()->pivot;
        $this->assertSame(GroupMemberRole::Member, $pivot->role);
    }

    public function test_a_user_cannot_join_the_same_group_twice(): void
    {
        $group = Group::factory()->create();
        $user = User::factory()->create();

        $group->members()->attach($user->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);

        $this->expectException(QueryException::class);
        $group->members()->attach($user->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
    }

    public function test_a_post_can_receive_comments_from_multiple_users(): void
    {
        $post = Post::factory()->create();
        $commenter = User::factory()->create();

        $comment = Comment::factory()->for($post)->create(['author_id' => $commenter->id]);

        $this->assertTrue($post->fresh()->comments->contains($comment));
        $this->assertSame($commenter->id, $comment->author->id);
    }

    public function test_deleting_a_group_cascades_to_its_posts_and_memberships(): void
    {
        $group = Group::factory()->create();
        $user = User::factory()->create();
        $group->members()->attach($user->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
        $post = Post::factory()->create(['group_id' => $group->id]);

        $group->delete();

        $this->assertDatabaseMissing('posts', ['id' => $post->id]);
        $this->assertDatabaseMissing('group_members', ['group_id' => $group->id]);
    }
}
