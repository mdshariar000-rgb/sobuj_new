<?php

namespace App\Services;

use App\Support\SocialSettings;
use Firebase\JWT\JWK;
use Firebase\JWT\JWT;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Throwable;

/**
 * Checks an ID token from "Sign in with Google" or "Sign in with Apple":
 * signed by that provider's published keys, not expired, issued by them,
 * and issued for this app. Returns who it's for.
 */
class SocialTokenVerifier
{
    private const PROVIDERS = [
        'google' => [
            'keys' => 'https://www.googleapis.com/oauth2/v3/certs',
            'issuers' => ['accounts.google.com', 'https://accounts.google.com'],
        ],
        'apple' => [
            'keys' => 'https://appleid.apple.com/auth/keys',
            'issuers' => ['https://appleid.apple.com'],
        ],
    ];

    /**
     * @return array{id: string, email: ?string, email_verified: bool, name: ?string}
     *
     * @throws InvalidSocialToken when the token isn't a valid one for this app
     * @throws RuntimeException when the provider's keys can't be fetched
     *
     * $evenIfSwitchedOff: for confirming an account deletion, which must keep
     * working after a provider is switched off in Settings.
     */
    public function verify(string $provider, string $idToken, ?string $rawNonce = null, bool $evenIfSwitchedOff = false): array
    {
        $audiences = $this->audiences($provider, $evenIfSwitchedOff);
        if ($audiences === []) {
            throw new InvalidSocialToken(ucfirst($provider).' sign-in isn\'t set up yet.');
        }

        // Fetched first: an unreachable provider is an outage, not a bad token
        // (the JWT library's own errors are RuntimeExceptions too).
        $keys = $this->keys($provider);

        try {
            $claims = (array) JWT::decode($idToken, JWK::parseKeySet($keys, 'RS256'));
        } catch (Throwable $e) {
            throw new InvalidSocialToken('That sign-in has expired or isn\'t valid. Please try again.', previous: $e);
        }

        if (! in_array($claims['iss'] ?? null, self::PROVIDERS[$provider]['issuers'], true)) {
            throw new InvalidSocialToken('That sign-in isn\'t valid.');
        }

        $tokenAudiences = (array) ($claims['aud'] ?? []);
        if (array_intersect($tokenAudiences, $audiences) === []) {
            throw new InvalidSocialToken('That sign-in was for a different app.');
        }

        // Apple: the app sends the raw nonce; the token carries its SHA-256.
        if ($rawNonce !== null && ! hash_equals(hash('sha256', $rawNonce), (string) ($claims['nonce'] ?? ''))) {
            throw new InvalidSocialToken('That sign-in isn\'t valid.');
        }

        if (blank($claims['sub'] ?? null)) {
            throw new InvalidSocialToken('That sign-in isn\'t valid.');
        }

        $verified = $claims['email_verified'] ?? false;

        return [
            'id' => (string) $claims['sub'],
            'email' => isset($claims['email']) ? mb_strtolower((string) $claims['email']) : null,
            // Apple sends "true" as a string.
            'email_verified' => $verified === true || $verified === 'true',
            'name' => isset($claims['name']) ? (string) $claims['name'] : null,
        ];
    }

    /** @return list<string> the client ids a token may be issued for; empty when switched off */
    public function audiences(string $provider, bool $evenIfSwitchedOff = false): array
    {
        $settings = SocialSettings::all();

        return match ($provider) {
            'google' => $evenIfSwitchedOff || SocialSettings::googleEnabled($settings)
                ? SocialSettings::googleClientIds($settings) : [],
            'apple' => $evenIfSwitchedOff || SocialSettings::appleEnabled($settings)
                ? array_values(array_filter([SocialSettings::appleClientId($settings)])) : [],
            default => [],
        };
    }

    /** The provider's public signing keys, cached for an hour. */
    private function keys(string $provider): array
    {
        return Cache::remember("social-jwks:{$provider}", now()->addHour(), function () use ($provider) {
            try {
                $response = Http::timeout(8)->acceptJson()->get(self::PROVIDERS[$provider]['keys']);
            } catch (ConnectionException $e) {
                throw new RuntimeException("Couldn't reach {$provider} to check the sign-in.", previous: $e);
            }

            if (! $response->successful() || ! is_array($response->json('keys'))) {
                throw new RuntimeException("{$provider} returned {$response->status()} for its keys.");
            }

            return $response->json();
        });
    }
}
