<?php

namespace Tests\Feature\Api;

use App\Filament\Resources\GroupRequestResource;
use App\Models\Group;
use App\Models\GroupRequest;
use App\Models\User;
use App\Services\AutoGroupService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AutoGroupTest extends TestCase
{
    use RefreshDatabase;

    private function register(array $overrides = []): User
    {
        $response = $this->postJson('/api/v1/auth/register', array_merge([
            'name' => 'Grower',
            'email' => fake()->unique()->safeEmail(),
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'latitude' => 53.8,
            'longitude' => -1.55,
            'address_line1' => '1 Test Street',
            'address_city' => 'Leeds',
            'address_postcode' => 'LS6 3AA',
            'location_label' => 'Headingley, Leeds, England',
        ], $overrides));
        $response->assertCreated();

        return User::findOrFail($response->json('data.id'));
    }

    public function test_town_is_the_last_part_of_the_label_before_the_country(): void
    {
        $this->assertSame('Leeds', AutoGroupService::townFrom('Headingley, Leeds, England'));
        $this->assertSame('Leeds', AutoGroupService::townFrom('LS6 3AA, Headingley, Leeds, England'));
        $this->assertSame('Manchester', AutoGroupService::townFrom('Manchester, England'));
        $this->assertSame('Cardiff', AutoGroupService::townFrom('Cardiff'));
        $this->assertNull(AutoGroupService::townFrom(null));
        $this->assertNull(AutoGroupService::townFrom(' , '));
    }

    public function test_signing_up_creates_and_joins_no_groups(): void
    {
        $user = $this->register([
            'growing_interests' => ['Sustainability', 'Seller'],
            'growing_setup' => 'allotment',
            'experience_level' => 'beginner',
        ]);

        $this->assertSame(0, Group::count());
        $this->assertSame(0, $user->groups()->count());
    }

    public function test_changing_profile_answers_joins_no_groups(): void
    {
        $user = $this->register();
        Sanctum::actingAs($user);

        $this->patchJson('/api/v1/auth/me', [
            'location_label' => 'Bristol, England',
            'growing_setup' => 'greenhouse',
        ])->assertOk();

        $this->assertSame(0, Group::count());
        $this->assertSame(0, $user->groups()->count());
    }

    public function test_suggested_groups_put_the_users_city_first(): void
    {
        $big = Group::factory()->create(['name' => 'UK Veg Growers']);
        $big->members()->attach(User::factory()->count(5)->create(['address_city' => 'Bristol']), ['role' => 'member', 'joined_at' => now()]);

        $herbs = Group::factory()->create(['name' => 'Herb Lovers']);
        $herbs->members()->attach(User::factory()->count(2)->create(['address_city' => 'Leeds']), ['role' => 'member', 'joined_at' => now()]);

        $leedsGroup = Group::factory()->create(['name' => 'Leeds Allotments']);

        $user = $this->register();
        Sanctum::actingAs($user);

        $response = $this->getJson('/api/v1/groups/suggested')->assertOk();

        $response->assertJsonPath('meta.city', 'Leeds');
        $this->assertSame(
            [$leedsGroup->id, $herbs->id, $big->id],
            array_column($response->json('data'), 'id'),
        );
        $response->assertJsonPath('data.0.is_local', true);
        $response->assertJsonPath('data.1.is_local', true);
        $response->assertJsonPath('data.1.local_members_count', 2);
        $response->assertJsonPath('data.2.is_local', false);
        $response->assertJsonPath('data.0.is_member', false);
    }

    public function test_the_groups_list_puts_my_groups_first_then_my_citys(): void
    {
        $user = $this->register();
        $other = User::factory()->create();

        $big = Group::factory()->create(['name' => 'UK Veg Growers']);
        $big->members()->attach(User::factory()->count(4)->create(), ['role' => 'member', 'joined_at' => now()]);
        $leeds = Group::factory()->create(['name' => 'Leeds Allotments']);
        $quiet = Group::factory()->create(['name' => 'Quiet Group']);
        $chatty = Group::factory()->create(['name' => 'Chatty Group']);
        foreach ([$quiet, $chatty] as $group) {
            $group->members()->attach($user->id, ['role' => 'member', 'joined_at' => now(), 'last_read_message_id' => 0]);
            $group->members()->attach($other->id, ['role' => 'member', 'joined_at' => now()]);
        }
        $chatty->messages()->create(['sender_id' => $other->id, 'body' => 'Anyone around?']);

        Sanctum::actingAs($user);
        $response = $this->getJson('/api/v1/groups')->assertOk();

        $this->assertSame(
            ['Chatty Group', 'Quiet Group', 'Leeds Allotments', 'UK Veg Growers'],
            array_column($response->json('data'), 'name'),
        );
        $this->assertNotNull($response->json('data.0.last_activity_at'));
    }

    public function test_the_groups_list_can_be_split_into_mine_and_others(): void
    {
        $user = User::factory()->create();
        $mine = Group::factory()->create(['name' => 'Mine']);
        $mine->members()->attach($user->id, ['role' => 'member', 'joined_at' => now()]);
        Group::factory()->create(['name' => 'Not mine']);

        Sanctum::actingAs($user);

        $this->assertSame(['Mine'], array_column($this->getJson('/api/v1/groups?membership=mine')->json('data'), 'name'));
        $this->assertSame(['Not mine'], array_column($this->getJson('/api/v1/groups?membership=others')->json('data'), 'name'));
        $this->assertCount(2, $this->getJson('/api/v1/groups')->json('data'));
    }

    public function test_unknown_interests_are_rejected_at_sign_up(): void
    {
        $this->postJson('/api/v1/auth/register', [
            'name' => 'Grower',
            'email' => 'grower@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'latitude' => 53.8,
            'longitude' => -1.55,
            'address_line1' => '1 Test Street',
            'address_city' => 'Leeds',
            'address_postcode' => 'LS6 3AA',
            'growing_interests' => ['Made up interest'],
        ])->assertUnprocessable()->assertJsonValidationErrors('growing_interests.0');
    }

    public function test_users_cannot_create_groups_but_admins_can(): void
    {
        Sanctum::actingAs(User::factory()->create());
        $this->postJson('/api/v1/groups', ['name' => 'My group', 'slug' => 'my-group'])->assertForbidden();

        Sanctum::actingAs(User::factory()->create(['is_admin' => true]));
        $this->postJson('/api/v1/groups', ['name' => 'My group', 'slug' => 'my-group'])->assertCreated();
    }

    public function test_a_user_can_request_a_group_and_an_admin_approval_creates_it(): void
    {
        $user = User::factory()->create();
        Sanctum::actingAs($user);

        $this->postJson('/api/v1/group-requests', [
            'name' => 'Junior Ambassadors',
            'description' => 'For young growers',
        ])->assertCreated()->assertJsonPath('data.status', 'pending');

        $request = GroupRequest::firstOrFail();
        $group = GroupRequestResource::approve($request);

        $this->assertSame('approved', $request->fresh()->status);
        $this->assertSame('Junior Ambassadors', $group->name);
        $this->assertSame('admin', $group->members()->whereKey($user->id)->first()->pivot->role->value);
    }

    public function test_a_group_request_needs_a_name(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->postJson('/api/v1/group-requests', [])->assertUnprocessable()->assertJsonValidationErrors('name');
    }
}
