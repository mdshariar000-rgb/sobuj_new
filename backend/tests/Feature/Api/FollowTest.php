<?php

namespace Tests\Feature\Api;

use App\Enums\NotificationType;
use App\Models\AppNotification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FollowTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_user_can_follow_and_unfollow_another_user(): void
    {
        $me = User::factory()->create();
        $grower = User::factory()->create();
        Sanctum::actingAs($me);

        $response = $this->postJson("/api/v1/users/{$grower->id}/follow");
        $response->assertOk();
        $response->assertJsonPath('data.is_following', true);
        $response->assertJsonPath('data.followers_count', 1);
        $this->assertSame(1, $me->following()->count());

        $response = $this->deleteJson("/api/v1/users/{$grower->id}/follow");
        $response->assertOk();
        $response->assertJsonPath('data.is_following', false);
        $response->assertJsonPath('data.followers_count', 0);
        $this->assertSame(0, $me->following()->count());
    }

    public function test_following_is_idempotent(): void
    {
        $me = User::factory()->create();
        $grower = User::factory()->create();
        Sanctum::actingAs($me);

        $this->postJson("/api/v1/users/{$grower->id}/follow")->assertOk();
        $this->postJson("/api/v1/users/{$grower->id}/follow")->assertOk();

        $this->assertSame(1, $me->following()->count());
        $this->assertSame(1, AppNotification::query()->count());
    }

    public function test_you_cannot_follow_yourself(): void
    {
        $me = User::factory()->create();
        Sanctum::actingAs($me);

        $this->postJson("/api/v1/users/{$me->id}/follow")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('user');
    }

    public function test_you_cannot_follow_a_blocked_user_or_someone_who_blocked_you(): void
    {
        $me = User::factory()->create();
        $blocked = User::factory()->create();
        Sanctum::actingAs($me);
        $this->postJson("/api/v1/users/{$blocked->id}/block")->assertOk();

        $this->postJson("/api/v1/users/{$blocked->id}/follow")->assertNotFound();

        // And the reverse: someone who blocked me can't be followed either.
        $blocker = User::factory()->create();
        Sanctum::actingAs($blocker);
        $this->postJson("/api/v1/users/{$me->id}/block")->assertOk();

        Sanctum::actingAs($me);
        $this->postJson("/api/v1/users/{$blocker->id}/follow")->assertNotFound();
    }

    public function test_following_someone_sends_them_a_notification_but_not_on_a_repeat_follow(): void
    {
        $me = User::factory()->create();
        $grower = User::factory()->create();
        Sanctum::actingAs($me);

        $this->postJson("/api/v1/users/{$grower->id}/follow")->assertOk();

        $this->assertDatabaseHas('app_notifications', [
            'recipient_id' => $grower->id,
            'actor_id' => $me->id,
            'type' => NotificationType::UserFollowed->value,
        ]);

        $this->deleteJson("/api/v1/users/{$grower->id}/follow")->assertOk();
        $this->postJson("/api/v1/users/{$grower->id}/follow")->assertOk();

        $this->assertSame(1, AppNotification::query()->count());
    }

    public function test_following_yourself_notification_guard_also_applies_here(): void
    {
        // Belt-and-suspenders: NotificationService::notify() already no-ops
        // when actor === recipient, and the controller rejects self-follow
        // before that point is ever reached.
        $me = User::factory()->create();
        Sanctum::actingAs($me);

        $this->postJson("/api/v1/users/{$me->id}/follow")->assertUnprocessable();
        $this->assertSame(0, AppNotification::query()->count());
    }

    public function test_followers_and_following_lists_return_the_right_users(): void
    {
        $grower = User::factory()->create();
        $fan1 = User::factory()->create();
        $fan2 = User::factory()->create();
        $someoneElse = User::factory()->create();

        Sanctum::actingAs($fan1);
        $this->postJson("/api/v1/users/{$grower->id}/follow")->assertOk();
        Sanctum::actingAs($fan2);
        $this->postJson("/api/v1/users/{$grower->id}/follow")->assertOk();
        $this->postJson("/api/v1/users/{$someoneElse->id}/follow")->assertOk();

        Sanctum::actingAs($grower);
        $followerIds = collect($this->getJson("/api/v1/users/{$grower->id}/followers")->assertOk()->json('data'))->pluck('id');
        $this->assertEqualsCanonicalizing([$fan1->id, $fan2->id], $followerIds->all());

        Sanctum::actingAs($fan2);
        $followingIds = collect($this->getJson("/api/v1/users/{$fan2->id}/following")->assertOk()->json('data'))->pluck('id');
        $this->assertEqualsCanonicalizing([$grower->id, $someoneElse->id], $followingIds->all());
    }

    public function test_a_blocked_users_followers_and_following_lists_404(): void
    {
        $me = User::factory()->create();
        $blocked = User::factory()->create();
        Sanctum::actingAs($me);
        $this->postJson("/api/v1/users/{$blocked->id}/block")->assertOk();

        $this->getJson("/api/v1/users/{$blocked->id}/followers")->assertNotFound();
        $this->getJson("/api/v1/users/{$blocked->id}/following")->assertNotFound();
    }

    public function test_a_blocked_user_is_hidden_from_a_shared_followers_list(): void
    {
        $grower = User::factory()->create();
        $me = User::factory()->create();
        $blocked = User::factory()->create();

        Sanctum::actingAs($me);
        $this->postJson("/api/v1/users/{$blocked->id}/block")->assertOk();

        Sanctum::actingAs($blocked);
        $this->postJson("/api/v1/users/{$grower->id}/follow")->assertOk();
        Sanctum::actingAs($me);
        $this->postJson("/api/v1/users/{$grower->id}/follow")->assertOk();

        $followerIds = collect($this->getJson("/api/v1/users/{$grower->id}/followers")->assertOk()->json('data'))->pluck('id');
        $this->assertTrue($followerIds->contains($me->id));
        $this->assertFalse($followerIds->contains($blocked->id));
    }

    public function test_me_and_show_include_follow_counts_and_is_following(): void
    {
        $me = User::factory()->create();
        $grower = User::factory()->create();
        Sanctum::actingAs($me);
        $this->postJson("/api/v1/users/{$grower->id}/follow")->assertOk();

        $this->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.following_count', 1)
            ->assertJsonPath('data.followers_count', 0);

        $this->getJson("/api/v1/users/{$grower->id}")
            ->assertOk()
            ->assertJsonPath('data.is_following', true)
            ->assertJsonPath('data.followers_count', 1);
    }
}
