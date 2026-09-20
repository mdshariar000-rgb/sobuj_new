<?php

namespace Tests\Feature\AgroHub;

use App\Models\AppNotification;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class NotificationInboxTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_notifications_list_only_shows_the_authenticated_users_own_notifications(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        AppNotification::factory()->create(['recipient_id' => $user->id, 'title' => 'Mine']);
        AppNotification::factory()->create(['recipient_id' => $other->id, 'title' => 'Not mine']);

        Sanctum::actingAs($user);
        $response = $this->getJson('/api/v1/notifications');

        $response->assertOk();
        $response->assertJsonCount(1, 'data');
        $response->assertJsonPath('data.0.title', 'Mine');
    }

    public function test_the_unread_count_reflects_only_unread_notifications(): void
    {
        $user = User::factory()->create();
        AppNotification::factory()->count(2)->create(['recipient_id' => $user->id]);
        AppNotification::factory()->read()->create(['recipient_id' => $user->id]);

        Sanctum::actingAs($user);
        $response = $this->getJson('/api/v1/notifications/unread-count');

        $response->assertOk();
        $response->assertJsonPath('unread_count', 2);
    }

    public function test_marking_one_notification_read_is_idempotent(): void
    {
        $user = User::factory()->create();
        $notification = AppNotification::factory()->create(['recipient_id' => $user->id]);
        Sanctum::actingAs($user);

        $this->postJson("/api/v1/notifications/{$notification->id}/read")->assertOk();
        $firstReadAt = $notification->fresh()->read_at;

        $this->postJson("/api/v1/notifications/{$notification->id}/read")->assertOk();
        $secondReadAt = $notification->fresh()->read_at;

        $this->assertNotNull($firstReadAt);
        $this->assertTrue($firstReadAt->equalTo($secondReadAt));
    }

    public function test_a_user_cannot_mark_another_users_notification_read(): void
    {
        $owner = User::factory()->create();
        $notification = AppNotification::factory()->create(['recipient_id' => $owner->id]);

        $intruder = User::factory()->create();
        Sanctum::actingAs($intruder);

        $this->postJson("/api/v1/notifications/{$notification->id}/read")->assertForbidden();
        $this->assertNull($notification->fresh()->read_at);
    }

    public function test_mark_all_read_only_touches_the_callers_own_unread_notifications(): void
    {
        $user = User::factory()->create();
        $other = User::factory()->create();
        AppNotification::factory()->count(3)->create(['recipient_id' => $user->id]);
        $othersNotification = AppNotification::factory()->create(['recipient_id' => $other->id]);

        Sanctum::actingAs($user);
        $this->postJson('/api/v1/notifications/read-all')->assertOk();

        $this->assertSame(0, $user->appNotifications()->whereNull('read_at')->count());
        $this->assertNull($othersNotification->fresh()->read_at);
    }
}
