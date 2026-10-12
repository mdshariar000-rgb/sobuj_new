<?php

namespace Tests\Feature\Api;

use App\Enums\GroupMemberRole;
use App\Enums\GroupVisibility;
use App\Models\Group;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class OnboardingAndFeedTest extends TestCase
{
    use RefreshDatabase;

    private function join(User $user, Group $group): void
    {
        $group->members()->attach($user->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
    }

    public function test_a_profile_post_list_includes_group_posts_the_viewer_can_see(): void
    {
        $viewer = User::factory()->create();
        $author = User::factory()->create();
        $public = Group::factory()->create();
        $joinedPrivate = Group::factory()->create(['visibility' => GroupVisibility::Private]);
        $otherPrivate = Group::factory()->create(['visibility' => GroupVisibility::Private]);
        $this->join($viewer, $joinedPrivate);
        Post::factory()->create(['author_id' => $author->id, 'body' => 'General']);
        Post::factory()->create(['author_id' => $author->id, 'body' => 'In public group', 'group_id' => $public->id]);
        Post::factory()->create(['author_id' => $author->id, 'body' => 'In my private group', 'group_id' => $joinedPrivate->id]);
        Post::factory()->create(['author_id' => $author->id, 'body' => 'In a stranger private group', 'group_id' => $otherPrivate->id]);
        $pending = Post::factory()->create(['author_id' => $author->id, 'body' => 'Awaiting approval', 'group_id' => $public->id]);
        $pending->approval_status = 'pending';
        $pending->save();

        Sanctum::actingAs($viewer);
        $response = $this->getJson("/api/v1/users/{$author->id}/posts")->assertOk();
        $bodies = array_column($response->json('data'), 'body');

        $this->assertEqualsCanonicalizing(['General', 'In public group', 'In my private group'], $bodies);
        $groupPost = collect($response->json('data'))->firstWhere('body', 'In public group');
        $this->assertSame($public->name, $groupPost['group']['name']);
    }

    public function test_on_their_own_profile_an_author_sees_all_their_group_posts_including_pending(): void
    {
        $author = User::factory()->create();
        $private = Group::factory()->create(['visibility' => GroupVisibility::Private]);
        Post::factory()->create(['author_id' => $author->id, 'body' => 'Private group post', 'group_id' => $private->id]);
        $pending = Post::factory()->create(['author_id' => $author->id, 'body' => 'Awaiting approval', 'group_id' => $private->id]);
        $pending->approval_status = 'pending';
        $pending->save();

        Sanctum::actingAs($author);
        $bodies = array_column($this->getJson("/api/v1/users/{$author->id}/posts")->json('data'), 'body');

        $this->assertEqualsCanonicalizing(['Private group post', 'Awaiting approval'], $bodies);
    }

    public function test_suggested_growers_are_nearest_first_and_skip_ineligible_accounts(): void
    {
        $viewer = User::factory()->create();
        $viewer->setLocation(53.80, -1.55)->save(); // Leeds

        $near = User::factory()->create(['name' => 'Near']);
        $near->setLocation(53.82, -1.57)->save();
        $farther = User::factory()->create(['name' => 'Farther']);
        $farther->setLocation(53.48, -2.24)->save(); // Manchester
        $alreadyFollowed = User::factory()->create(['name' => 'Followed']);
        $alreadyFollowed->setLocation(53.81, -1.56)->save();
        $blocked = User::factory()->create(['name' => 'Blocked']);
        $blocked->setLocation(53.81, -1.56)->save();
        $suspended = User::factory()->create(['name' => 'Suspended', 'is_suspended' => true]);
        $suspended->setLocation(53.81, -1.56)->save();

        $viewer->following()->attach($alreadyFollowed->id, ['created_at' => now()]);
        DB::table('user_blocks')->insert(['blocker_id' => $blocked->id, 'blocked_id' => $viewer->id, 'created_at' => now()]);

        Sanctum::actingAs($viewer);
        $names = array_column($this->getJson('/api/v1/users/suggested')->assertOk()->json('data'), 'name');

        $this->assertSame(['Near', 'Farther'], array_slice($names, 0, 2));
        foreach (['Followed', 'Blocked', 'Suspended', $viewer->name] as $excluded) {
            $this->assertNotContains($excluded, $names);
        }
    }

    public function test_suggested_groups_without_a_city_are_public_ones_biggest_first(): void
    {
        $viewer = User::factory()->create();
        $small = Group::factory()->create(['name' => 'Small']);
        $big = Group::factory()->create(['name' => 'Big']);
        Group::factory()->create(['name' => 'Private', 'visibility' => GroupVisibility::Private]);
        foreach (User::factory()->count(3)->create() as $member) {
            $this->join($member, $big);
        }
        $this->join(User::factory()->create(), $small);

        Sanctum::actingAs($viewer);
        $response = $this->getJson('/api/v1/groups/suggested')->assertOk();

        $this->assertSame(['Big', 'Small'], array_column($response->json('data'), 'name'));
        $response->assertJsonPath('meta.city', null);
    }

    public function test_a_new_user_is_in_no_groups_and_sees_their_city_suggested_first(): void
    {
        $other = Group::factory()->create(['name' => 'Allotment Keepers']);
        $this->join(User::factory()->create(), $other);
        Group::factory()->create(['name' => 'Leeds Growers']);

        $token = $this->postJson('/api/v1/auth/register', [
            'name' => 'New Grower',
            'email' => 'new-grower@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'latitude' => 53.8,
            'longitude' => -1.55,
            'location_label' => 'Headingley, Leeds, England',
            'address_line1' => '1 Test Road',
            'address_city' => 'Leeds',
            'address_postcode' => 'LS6 3AA',
        ])->assertCreated()->json('token');

        $groups = $this->withToken($token)->getJson('/api/v1/groups/suggested')->assertOk()->json('data');

        $this->assertSame(['Leeds Growers', 'Allotment Keepers'], array_column($groups, 'name'));
        $this->assertSame([false, false], array_column($groups, 'is_member'));
        $this->assertSame([true, false], array_column($groups, 'is_local'));
    }
}
