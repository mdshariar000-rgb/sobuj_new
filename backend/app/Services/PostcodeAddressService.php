<?php

namespace App\Services;

use App\Models\Setting;
use App\Support\UkAddress;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * Every address at a UK postcode, from Royal Mail's address file via Ideal
 * Postcodes — the app's "type your postcode, pick your address" step. Paid
 * per lookup (an unknown postcode is free), so results are cached for a
 * day. The API key is set on the admin Settings page; without one this
 * reports itself unavailable and the app asks for the street by hand.
 */
class PostcodeAddressService
{
    public const SETTING_KEY = 'ideal_postcodes_api_key';

    public function isConfigured(): bool
    {
        return filled($this->apiKey());
    }

    /**
     * Null when the postcode doesn't exist.
     *
     * @return list<array{id: string, address: string, line1: string, line2: ?string, city: string, county: ?string, postcode: string, latitude: ?float, longitude: ?float}>|null
     *
     * @throws RuntimeException when the service isn't set up or can't be reached
     */
    public function lookup(string $postcode): ?array
    {
        $key = $this->apiKey();
        if (blank($key)) {
            throw new RuntimeException('Postcode lookup has no API key.');
        }

        $postcode = (string) UkAddress::normalisePostcode($postcode);

        return Cache::remember('postcode-addresses:'.$postcode, now()->addDay(), function () use ($key, $postcode) {
            try {
                $response = Http::timeout(8)
                    ->acceptJson()
                    ->get(rtrim((string) config('services.ideal_postcodes.url'), '/').'/v1/postcodes/'.rawurlencode($postcode), [
                        'api_key' => $key,
                    ]);
            } catch (ConnectionException $e) {
                throw new RuntimeException('Postcode lookup is unavailable.', previous: $e);
            }

            if ($response->status() === 404 && $response->json('code') === 4040) {
                return null;
            }

            if (! $response->successful() || $response->json('code') !== 2000) {
                // e.g. a bad key or no lookups left — the admin needs to know.
                throw new RuntimeException('Ideal Postcodes returned '.$response->status().': '.$response->json('message'));
            }

            return collect($response->json('result') ?? [])
                ->filter(fn ($row) => is_array($row) && filled($row['line_1'] ?? null))
                ->map(fn (array $row) => $this->toAddress($row))
                ->values()
                ->all();
        });
    }

    private function toAddress(array $row): array
    {
        $line1 = trim((string) $row['line_1']);
        // line_2/line_3 are both optional; the app has one second line.
        $line2 = collect([$row['line_2'] ?? null, $row['line_3'] ?? null])
            ->map(fn ($line) => trim((string) $line))
            ->filter()
            ->implode(', ');
        $city = Str::title(mb_strtolower(trim((string) ($row['post_town'] ?? ''))));
        $county = trim((string) ($row['county'] ?? '')) ?: null;
        $postcode = (string) UkAddress::normalisePostcode($row['postcode'] ?? '');

        return [
            'id' => (string) ($row['id'] ?? $row['udprn'] ?? Str::uuid()),
            'address' => implode(', ', array_filter([$line1, $line2, $city, $postcode])),
            'line1' => $line1,
            'line2' => $line2 !== '' ? $line2 : null,
            'city' => $city,
            'county' => $county,
            'postcode' => $postcode,
            'latitude' => isset($row['latitude']) ? (float) $row['latitude'] : null,
            'longitude' => isset($row['longitude']) ? (float) $row['longitude'] : null,
        ];
    }

    private function apiKey(): ?string
    {
        return Setting::get(self::SETTING_KEY) ?: config('services.ideal_postcodes.key');
    }
}
