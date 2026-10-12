<?php

namespace Tests\Feature\Api;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class AddressLookupTest extends TestCase
{
    use RefreshDatabase;

    private function feature(array $properties, float $lon = -1.5778, float $lat = 53.8174): array
    {
        return [
            'type' => 'Feature',
            'geometry' => ['type' => 'Point', 'coordinates' => [$lon, $lat]],
            'properties' => array_merge(['countrycode' => 'GB', 'osm_type' => 'N', 'osm_id' => random_int(1, 999999)], $properties),
        ];
    }

    private function fakePhoton(array $features): void
    {
        Http::fake(['photon.komoot.io/*' => Http::response(['type' => 'FeatureCollection', 'features' => $features])]);
    }

    public function test_house_suggestions_carry_the_whole_address_without_signing_in(): void
    {
        $this->fakePhoton([$this->feature([
            'type' => 'house', 'housenumber' => '1', 'street' => 'High Street',
            'postcode' => 'bs9 3dr', 'city' => 'Bristol', 'county' => 'Bristol',
        ], -2.6183, 51.4929)]);

        $this->getJson('/api/v1/addresses/suggest?q=1 high street bristol')
            ->assertOk()
            ->assertJsonPath('data.0.address', '1 High Street, Bristol, BS9 3DR')
            ->assertJsonPath('data.0.line1', '1 High Street')
            ->assertJsonPath('data.0.city', 'Bristol')
            ->assertJsonPath('data.0.postcode', 'BS9 3DR')
            ->assertJsonPath('data.0.latitude', 51.4929);

        Http::assertSent(fn ($request) => str_contains($request->url(), 'layer=house&layer=street')
            && str_contains($request->url(), 'bbox='));
    }

    public function test_a_street_match_keeps_the_typed_house_number(): void
    {
        $this->fakePhoton([$this->feature([
            'type' => 'street', 'name' => 'Cardigan Road', 'postcode' => 'LS6 3AF',
            'city' => 'Leeds', 'county' => 'West Yorkshire',
        ])]);

        $this->getJson('/api/v1/addresses/suggest?q=12 cardigan road')
            ->assertOk()
            ->assertJsonPath('data.0.line1', '12 Cardigan Road')
            ->assertJsonPath('data.0.county', 'West Yorkshire');
    }

    public function test_a_named_building_goes_on_the_first_line(): void
    {
        $this->fakePhoton([$this->feature([
            'type' => 'house', 'name' => 'Sherlock Holmes Museum', 'housenumber' => '221B',
            'street' => 'Baker Street', 'postcode' => 'NW1 6XE', 'city' => 'London',
        ])]);

        $this->getJson('/api/v1/addresses/suggest?q=221b baker street')
            ->assertJsonPath('data.0.line1', 'Sherlock Holmes Museum')
            ->assertJsonPath('data.0.line2', '221B Baker Street');
    }

    public function test_non_uk_and_duplicate_results_are_dropped(): void
    {
        $house = ['type' => 'house', 'housenumber' => '5', 'street' => 'Main Street', 'postcode' => 'G1 1AA', 'city' => 'Glasgow'];
        $this->fakePhoton([
            $this->feature($house),
            $this->feature($house),
            $this->feature(['type' => 'house', 'countrycode' => 'IE', 'housenumber' => '5', 'street' => 'Main Street', 'city' => 'Dublin']),
        ]);

        $this->assertCount(1, $this->getJson('/api/v1/addresses/suggest?q=5 main street')->json('data'));
    }

    public function test_when_photon_is_down_the_app_is_told_it_is_unavailable(): void
    {
        Http::fake(['photon.komoot.io/*' => Http::response('', 502)]);

        $this->getJson('/api/v1/addresses/suggest?q=12 cardigan road')->assertStatus(503);
    }

    public function test_a_search_needs_three_characters(): void
    {
        $this->getJson('/api/v1/addresses/suggest?q=12')->assertUnprocessable();
    }
}
