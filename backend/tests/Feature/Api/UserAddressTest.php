<?php

namespace Tests\Feature\Api;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UserAddressTest extends TestCase
{
    use RefreshDatabase;

    private function payload(array $overrides = []): array
    {
        return array_merge([
            'name' => 'Rina',
            'email' => 'rina@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'latitude' => 53.82,
            'longitude' => -1.58,
            'location_label' => 'Headingley, Leeds, England',
            'address_line1' => '12 Cardigan Road',
            'address_line2' => 'Flat 3',
            'address_city' => 'Leeds',
            'address_county' => 'West Yorkshire',
            'address_postcode' => 'ls6  3aa',
        ], $overrides);
    }

    public function test_sign_up_saves_the_full_address_with_a_tidied_postcode(): void
    {
        $this->postJson('/api/v1/auth/register', $this->payload())
            ->assertCreated()
            ->assertJsonPath('data.address.line1', '12 Cardigan Road')
            ->assertJsonPath('data.address.postcode', 'LS6 3AA')
            ->assertJsonPath('data.needs_address', false);
    }

    public function test_sign_up_needs_line_1_town_and_a_real_uk_postcode(): void
    {
        $this->postJson('/api/v1/auth/register', $this->payload([
            'address_line1' => '',
            'address_city' => '',
            'address_postcode' => '12345',
        ]))->assertUnprocessable()->assertJsonValidationErrors([
            'address_line1', 'address_city', 'address_postcode',
        ]);
    }

    public function test_the_address_is_private(): void
    {
        $owner = User::factory()->create(['address_line1' => '12 Cardigan Road', 'address_postcode' => 'LS6 3AA']);

        Sanctum::actingAs(User::factory()->create());
        $response = $this->getJson("/api/v1/users/{$owner->id}")->assertOk();
        $response->assertJsonMissingPath('data.address');
        $this->assertStringNotContainsString('Cardigan', $response->getContent());

        Sanctum::actingAs($owner);
        $this->getJson('/api/v1/auth/me')->assertJsonPath('data.address.line1', '12 Cardigan Road');
    }

    public function test_an_existing_account_without_an_address_is_asked_for_one_and_can_add_it(): void
    {
        $user = User::factory()->create(['address_postcode' => null]);
        Sanctum::actingAs($user);

        $this->getJson('/api/v1/auth/me')->assertJsonPath('data.needs_address', true);

        $this->patchJson('/api/v1/auth/me', [
            'address_line1' => '5 High Street',
            'address_city' => 'Bristol',
            'address_postcode' => 'BS1 4DJ',
            'latitude' => 51.45,
            'longitude' => -2.59,
            'location_label' => 'BS1 4DJ, Bristol, England',
        ])->assertOk()
            ->assertJsonPath('data.needs_address', false)
            ->assertJsonPath('data.address.city', 'Bristol');

        $coordinates = $user->fresh()->getExactCoordinates();
        $this->assertNotNull($coordinates);
    }

    public function test_a_profile_edit_cannot_blank_out_the_address(): void
    {
        Sanctum::actingAs(User::factory()->create(['address_postcode' => 'LS6 3AA']));

        $this->patchJson('/api/v1/auth/me', ['address_postcode' => ''])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('address_postcode');
    }
}
