<?php

namespace Tests\Feature\Api;

use App\Models\Setting;
use App\Models\User;
use App\Support\SocialSettings;
use Firebase\JWT\JWT;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SocialLoginTest extends TestCase
{
    use RefreshDatabase;

    private const GOOGLE_CLIENT = 'ios-client.apps.googleusercontent.com';

    private string $privateKey;

    protected function setUp(): void
    {
        parent::setUp();

        // A throwaway signing key standing in for Google's and Apple's.
        $key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);
        openssl_pkey_export($key, $pem);
        $this->privateKey = $pem;
        $rsa = openssl_pkey_get_details($key)['rsa'];
        $b64 = fn (string $bin) => rtrim(strtr(base64_encode($bin), '+/', '-_'), '=');
        $jwks = ['keys' => [[
            'kty' => 'RSA', 'alg' => 'RS256', 'use' => 'sig', 'kid' => 'test-key',
            'n' => $b64($rsa['n']), 'e' => $b64($rsa['e']),
        ]]];
        Http::fake([
            'www.googleapis.com/oauth2/v3/certs' => Http::response($jwks),
            'appleid.apple.com/auth/keys' => Http::response($jwks),
        ]);

        Setting::set(SocialSettings::GOOGLE_ENABLED, '1');
        Setting::set(SocialSettings::GOOGLE_IOS_CLIENT_ID, self::GOOGLE_CLIENT);
        Setting::set(SocialSettings::GOOGLE_SERVER_CLIENT_ID, 'web-client.apps.googleusercontent.com');
        Setting::set(SocialSettings::APPLE_ENABLED, '1');
    }

    private function googleToken(array $claims = []): string
    {
        return JWT::encode([
            'iss' => 'https://accounts.google.com',
            'aud' => self::GOOGLE_CLIENT,
            'sub' => 'google-123',
            'email' => 'Rina@Example.com',
            'email_verified' => true,
            'name' => 'Rina Akter',
            'iat' => time(),
            'exp' => time() + 3600,
            ...$claims,
        ], $this->privateKey, 'RS256', 'test-key');
    }

    private function appleToken(array $claims = []): string
    {
        return JWT::encode([
            'iss' => 'https://appleid.apple.com',
            'aud' => 'com.greenshelter.shobuj',
            'sub' => 'apple-001.abc',
            'email' => 'x7k2@privaterelay.appleid.com',
            'email_verified' => 'true',
            'nonce' => hash('sha256', 'raw-nonce'),
            'iat' => time(),
            'exp' => time() + 600,
            ...$claims,
        ], $this->privateKey, 'RS256', 'test-key');
    }

    private function address(): array
    {
        return [
            'address_line1' => '12 Cardigan Road',
            'address_city' => 'Leeds',
            'address_postcode' => 'ls6 3aa',
            'latitude' => 53.8173,
            'longitude' => -1.5776,
        ];
    }

    public function test_a_new_google_user_is_asked_to_finish_signing_up(): void
    {
        $this->postJson('/api/v1/auth/social', ['provider' => 'google', 'id_token' => $this->googleToken()])
            ->assertOk()
            ->assertJsonPath('needs_signup', true)
            ->assertJsonPath('email', 'rina@example.com')
            ->assertJsonPath('name', 'Rina Akter')
            ->assertJsonMissingPath('token');

        $this->assertDatabaseCount('users', 0);
    }

    public function test_finishing_sign_up_creates_the_account_with_the_address(): void
    {
        $response = $this->postJson('/api/v1/auth/social', [
            'provider' => 'google',
            'id_token' => $this->googleToken(),
            'name' => 'Rina Akter',
            ...$this->address(),
        ]);

        $response->assertCreated()
            ->assertJsonPath('is_new_user', true)
            ->assertJsonPath('data.email', 'rina@example.com')
            ->assertJsonStructure(['token']);
        $user = User::where('email', 'rina@example.com')->firstOrFail();
        $this->assertSame('google-123', $user->google_id);
        $this->assertSame('LS6 3AA', $user->address_postcode);
        $this->assertNotNull($user->email_verified_at);
    }

    public function test_an_existing_google_user_signs_straight_in(): void
    {
        $user = User::factory()->create(['google_id' => 'google-123', 'email' => 'other@example.com']);

        $this->postJson('/api/v1/auth/social', ['provider' => 'google', 'id_token' => $this->googleToken()])
            ->assertOk()
            ->assertJsonPath('data.id', $user->id)
            ->assertJsonPath('is_new_user', false)
            ->assertJsonStructure(['token']);
    }

    public function test_a_verified_email_links_to_the_existing_account(): void
    {
        $user = User::factory()->create(['email' => 'rina@example.com']);

        $this->postJson('/api/v1/auth/social', ['provider' => 'google', 'id_token' => $this->googleToken()])
            ->assertOk()
            ->assertJsonPath('data.id', $user->id);
        $this->assertSame('google-123', $user->fresh()->google_id);
    }

    public function test_an_unverified_email_does_not_link_to_an_existing_account(): void
    {
        User::factory()->create(['email' => 'rina@example.com']);

        $this->postJson('/api/v1/auth/social', [
            'provider' => 'google',
            'id_token' => $this->googleToken(['email_verified' => false]),
        ])->assertOk()->assertJsonPath('needs_signup', true);
    }

    public function test_apple_sign_in_checks_the_nonce_and_signs_in(): void
    {
        $user = User::factory()->create(['apple_id' => 'apple-001.abc']);

        $this->postJson('/api/v1/auth/social', [
            'provider' => 'apple',
            'id_token' => $this->appleToken(),
            'nonce' => 'raw-nonce',
        ])->assertOk()->assertJsonPath('data.id', $user->id);

        $this->postJson('/api/v1/auth/social', [
            'provider' => 'apple',
            'id_token' => $this->appleToken(),
            'nonce' => 'a-different-nonce',
        ])->assertUnauthorized();
    }

    public function test_a_new_apple_user_keeps_the_name_the_app_sends(): void
    {
        $this->postJson('/api/v1/auth/social', [
            'provider' => 'apple',
            'id_token' => $this->appleToken(),
            'nonce' => 'raw-nonce',
            'name' => 'Sam Patel',
            ...$this->address(),
        ])->assertCreated();

        $user = User::where('apple_id', 'apple-001.abc')->firstOrFail();
        $this->assertSame('Sam Patel', $user->name);
        $this->assertSame('x7k2@privaterelay.appleid.com', $user->email);
    }

    public function test_tokens_for_another_app_expired_or_forged_are_rejected(): void
    {
        $other = $this->googleToken(['aud' => 'someone-else.apps.googleusercontent.com']);
        $expired = $this->googleToken(['iat' => time() - 7200, 'exp' => time() - 3600]);
        $wrongIssuer = $this->googleToken(['iss' => 'https://evil.example.com']);

        foreach ([$other, $expired, $wrongIssuer, 'not-a-token'] as $token) {
            $this->postJson('/api/v1/auth/social', ['provider' => 'google', 'id_token' => $token])
                ->assertUnauthorized();
        }
        $this->assertDatabaseCount('users', 0);
    }

    public function test_google_sign_in_is_refused_until_client_ids_are_set(): void
    {
        Setting::set(SocialSettings::GOOGLE_ENABLED, '0');

        $this->postJson('/api/v1/auth/social', ['provider' => 'google', 'id_token' => $this->googleToken()])
            ->assertUnauthorized()
            ->assertJsonPath('message', "Google sign-in isn't set up yet.");
    }

    public function test_a_suspended_account_cannot_sign_in(): void
    {
        User::factory()->create(['google_id' => 'google-123', 'is_suspended' => true]);

        $this->postJson('/api/v1/auth/social', ['provider' => 'google', 'id_token' => $this->googleToken()])
            ->assertForbidden();
    }

    public function test_an_account_made_with_google_has_no_password_until_one_is_set(): void
    {
        $this->postJson('/api/v1/auth/social', [
            'provider' => 'google',
            'id_token' => $this->googleToken(),
            'name' => 'Rina Akter',
            ...$this->address(),
        ])->assertCreated()
            ->assertJsonPath('data.has_password', false)
            ->assertJsonPath('data.signed_in_with', ['google']);

        $user = User::where('google_id', 'google-123')->firstOrFail();
        $this->postJson('/api/v1/auth/login', ['email' => 'rina@example.com', 'password' => 'anything'])
            ->assertUnprocessable();

        // "Forgot password?" gives it a real one.
        DB::table('password_reset_tokens')->insert([
            'email' => 'rina@example.com', 'token' => Hash::make('123456'), 'created_at' => now(),
        ]);
        $this->postJson('/api/v1/auth/reset-password', [
            'email' => 'rina@example.com', 'code' => '123456',
            'password' => 'new-password-1', 'password_confirmation' => 'new-password-1',
        ])->assertOk();
        $this->assertTrue($user->fresh()->has_password);
    }

    public function test_a_google_account_is_deleted_by_signing_in_with_google_again(): void
    {
        $user = User::factory()->create(['google_id' => 'google-123', 'has_password' => false]);
        Sanctum::actingAs($user);

        $this->deleteJson('/api/v1/auth/me', [
            'provider' => 'google',
            'id_token' => $this->googleToken(['sub' => 'someone-else']),
        ])->assertUnprocessable()->assertJsonValidationErrors('id_token');
        $this->assertModelExists($user);

        $this->deleteJson('/api/v1/auth/me', ['provider' => 'google', 'id_token' => $this->googleToken()])
            ->assertOk();
        $this->assertModelMissing($user);
    }

    public function test_deleting_still_needs_the_password_or_a_token(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $this->deleteJson('/api/v1/auth/me', [])->assertUnprocessable()->assertJsonValidationErrors('password');
    }

    public function test_apple_is_refused_while_switched_off(): void
    {
        Setting::set(SocialSettings::APPLE_ENABLED, '0');

        $this->postJson('/api/v1/auth/social', [
            'provider' => 'apple', 'id_token' => $this->appleToken(), 'nonce' => 'raw-nonce',
        ])->assertUnauthorized();
    }

    public function test_the_app_reads_the_public_settings_but_never_the_apple_key(): void
    {
        Setting::set(SocialSettings::APPLE_PRIVATE_KEY, 'secret-key-material');

        $this->getJson('/api/v1/config/social')
            ->assertOk()
            ->assertExactJson(['data' => [
                'google' => [
                    'enabled' => true,
                    'ios_client_id' => self::GOOGLE_CLIENT,
                    'server_client_id' => 'web-client.apps.googleusercontent.com',
                ],
                'apple' => ['enabled' => true],
            ]]);

        Setting::set(SocialSettings::GOOGLE_ENABLED, '0');
        Setting::set(SocialSettings::APPLE_ENABLED, null);
        $this->getJson('/api/v1/config/social')
            ->assertJsonPath('data.google', ['enabled' => false, 'ios_client_id' => null, 'server_client_id' => null])
            ->assertJsonPath('data.apple.enabled', false);
    }

    public function test_deleting_an_apple_account_revokes_the_apple_link(): void
    {
        $key = openssl_pkey_new(['curve_name' => 'prime256v1', 'private_key_type' => OPENSSL_KEYTYPE_EC]);
        openssl_pkey_export($key, $p8);
        Setting::set(SocialSettings::APPLE_TEAM_ID, 'TEAM123456');
        Setting::set(SocialSettings::APPLE_KEY_ID, 'KEY1234567');
        Setting::set(SocialSettings::APPLE_PRIVATE_KEY, $p8);
        $this->fakeAppleTokenEndpoints();
        $user = User::factory()->create(['apple_id' => 'apple-001.abc', 'has_password' => false]);
        Sanctum::actingAs($user);

        $this->deleteJson('/api/v1/auth/me', [
            'provider' => 'apple',
            'id_token' => $this->appleToken(),
            'nonce' => 'raw-nonce',
            'authorization_code' => 'apple-auth-code',
        ])->assertOk();

        $this->assertModelMissing($user);
        Http::assertSent(fn ($r) => $r->url() === 'https://appleid.apple.com/auth/token'
            && $r['code'] === 'apple-auth-code'
            && $r['client_id'] === 'com.greenshelter.shobuj');
        Http::assertSent(fn ($r) => $r->url() === 'https://appleid.apple.com/auth/revoke'
            && $r['token'] === 'apple-refresh-token');
    }

    private function fakeAppleTokenEndpoints(): void
    {
        // Http::fake() merges, so the JWKS fakes from setUp still answer.
        Http::fake([
            'appleid.apple.com/auth/token' => Http::response(['access_token' => 'a', 'refresh_token' => 'apple-refresh-token']),
            'appleid.apple.com/auth/revoke' => Http::response(null, 200),
        ]);
    }

    public function test_an_apple_account_can_still_be_deleted_after_apple_is_switched_off(): void
    {
        Setting::set(SocialSettings::APPLE_ENABLED, '0');
        $user = User::factory()->create(['apple_id' => 'apple-001.abc', 'has_password' => false]);
        Sanctum::actingAs($user);

        $this->deleteJson('/api/v1/auth/me', [
            'provider' => 'apple', 'id_token' => $this->appleToken(), 'nonce' => 'raw-nonce',
        ])->assertOk();
        $this->assertModelMissing($user);
    }
}
