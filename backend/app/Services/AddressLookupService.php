<?php

namespace App\Services;

use App\Support\UkAddress;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use RuntimeException;

/**
 * UK address suggestions while typing, from OpenStreetMap via Photon
 * (photon.komoot.io) — free, no key. Each suggestion already holds the
 * whole address, so there's no second "get" call.
 *
 * The public Photon server is fair-use with no uptime promise: results are
 * cached, calls are rate limited per IP (routes/api.php), and when it's
 * down the app falls back to typing the address by hand. Point
 * PHOTON_URL at a self-hosted Photon to move off the public server.
 */
class AddressLookupService
{
    /** Roughly the UK: west, south, east, north. */
    private const UK_BBOX = '-8.65,49.86,1.77,60.86';

    private const LIMIT = 6;

    /**
     * @return list<array{id: string, address: string, line1: string, line2: ?string, city: string, county: ?string, postcode: ?string, latitude: float, longitude: float}>
     *
     * @throws RuntimeException when the service is unavailable
     */
    public function suggest(string $term): array
    {
        $term = trim($term);

        return Cache::remember('address-suggest:'.sha1(mb_strtolower($term)), now()->addHour(), function () use ($term) {
            try {
                $response = Http::timeout(6)
                    ->acceptJson()
                    // Photon's fair-use policy asks clients to identify themselves.
                    ->withUserAgent(config('app.name').' address lookup ('.config('app.url').')')
                    ->get(rtrim((string) config('services.photon.url'), '/').'/api/?'.http_build_query([
                        'q' => $term,
                        // Ask for spares: non-UK and duplicate hits are dropped below.
                        'limit' => self::LIMIT * 2,
                        'lang' => 'en',
                        'bbox' => self::UK_BBOX,
                    ]).'&layer=house&layer=street'); // Photon wants the key repeated, not layer[].
            } catch (ConnectionException $e) {
                throw new RuntimeException('Address lookup is unavailable.', previous: $e);
            }

            if (! $response->successful()) {
                throw new RuntimeException("Photon returned {$response->status()}.");
            }

            return collect($response->json('features') ?? [])
                ->map(fn ($feature) => is_array($feature) ? $this->toAddress($feature, $term) : null)
                ->filter()
                ->unique('address')
                ->take(self::LIMIT)
                ->values()
                ->all();
        });
    }

    /**
     * One Photon result as the app's address form expects it — or null if
     * it isn't a UK house or street.
     */
    private function toAddress(array $feature, string $term): ?array
    {
        $p = $feature['properties'] ?? [];
        [$longitude, $latitude] = $feature['geometry']['coordinates'] ?? [null, null];
        $city = $p['city'] ?? $p['district'] ?? null;

        if (($p['countrycode'] ?? null) !== 'GB' || $latitude === null || $city === null) {
            return null;
        }

        $street = $p['street'] ?? null;
        $number = $p['housenumber'] ?? null;
        $name = $p['name'] ?? null;

        if (($p['type'] ?? null) === 'street') {
            // A street match: keep the house number the user typed, if any.
            $typedNumber = preg_match('/^\s*(\d+[A-Za-z]?)\b/', $term, $m) ? $m[1].' ' : '';
            $line1 = $typedNumber.($name ?? '');
            $line2 = null;
        } else {
            $numberAndStreet = trim(($number ?? '').' '.($street ?? ''));
            // A named building ("Sherlock Holmes Museum") goes first.
            if ($name !== null && $numberAndStreet !== '' && $name !== $numberAndStreet && ! Str::startsWith($name, (string) $number)) {
                $line1 = $name;
                $line2 = $numberAndStreet;
            } else {
                $line1 = $numberAndStreet !== '' ? $numberAndStreet : (string) $name;
                $line2 = null;
            }
        }

        if (trim($line1) === '') {
            return null;
        }

        $postcode = isset($p['postcode']) ? UkAddress::normalisePostcode($p['postcode']) : null;

        return [
            'id' => ($p['osm_type'] ?? '').($p['osm_id'] ?? Str::random(8)),
            'address' => implode(', ', array_filter([$line1, $line2, $city, $postcode])),
            'line1' => $line1,
            'line2' => $line2,
            'city' => $city,
            'county' => $p['county'] ?? null,
            'postcode' => $postcode,
            'latitude' => (float) $latitude,
            'longitude' => (float) $longitude,
        ];
    }
}
