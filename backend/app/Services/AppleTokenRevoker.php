<?php

namespace App\Services;

use App\Support\SocialSettings;
use Firebase\JWT\JWT;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Throwable;

/**
 * Apple requires apps to revoke a "Sign in with Apple" link when the account
 * is deleted. The app sends a fresh authorization code from re-confirming
 * with Apple; it's exchanged for a token with a client secret signed by the
 * key from the admin Settings page, and that token is revoked.
 */
class AppleTokenRevoker
{
    private const BASE = 'https://appleid.apple.com/auth';

    public function isConfigured(): bool
    {
        return SocialSettings::appleKeyConfigured(SocialSettings::all());
    }

    /** @throws RuntimeException when Apple refuses */
    public function revoke(string $authorizationCode): void
    {
        $settings = SocialSettings::all();
        $clientId = (string) SocialSettings::appleClientId($settings);
        $secret = $this->clientSecret($settings, $clientId);

        $token = Http::asForm()->timeout(10)->post(self::BASE.'/token', [
            'client_id' => $clientId,
            'client_secret' => $secret,
            'code' => $authorizationCode,
            'grant_type' => 'authorization_code',
        ]);
        $refreshToken = $token->json('refresh_token');
        if (! $token->successful() || ! is_string($refreshToken)) {
            throw new RuntimeException('Apple token exchange failed: '.$token->status().' '.$token->json('error'));
        }

        $revoke = Http::asForm()->timeout(10)->post(self::BASE.'/revoke', [
            'client_id' => $clientId,
            'client_secret' => $secret,
            'token' => $refreshToken,
            'token_type_hint' => 'refresh_token',
        ]);
        if (! $revoke->successful()) {
            throw new RuntimeException('Apple revoke failed: '.$revoke->status());
        }
    }

    /** A short-lived ES256 JWT that proves the request comes from this app's team. */
    private function clientSecret(array $settings, string $clientId): string
    {
        try {
            return JWT::encode([
                'iss' => $settings[SocialSettings::APPLE_TEAM_ID],
                'iat' => time(),
                'exp' => time() + 300,
                'aud' => 'https://appleid.apple.com',
                'sub' => $clientId,
            ], (string) $settings[SocialSettings::APPLE_PRIVATE_KEY], 'ES256', $settings[SocialSettings::APPLE_KEY_ID]);
        } catch (Throwable $e) {
            throw new RuntimeException('The Apple private key in Settings is not a valid .p8 key.', previous: $e);
        }
    }
}
