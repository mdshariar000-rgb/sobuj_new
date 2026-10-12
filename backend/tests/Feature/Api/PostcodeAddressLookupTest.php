<?php

namespace Tests\Feature\Api;

use App\Models\Setting;
use App\Services\PostcodeAddressService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class PostcodeAddressLookupTest extends TestCase
{
    use RefreshDatabase;

    private function idealPostcodesFound(): array
    {
        return [
            'result' => [
                [
                    'postcode' => 'LS6 3AA',
                    'post_town' => 'LEEDS',
                    'line_1' => 'Flat 2',
                    'line_2' => '12 Cardigan Road',
                    'line_3' => '',
                    'county' => 'West Yorkshire',
                    'latitude' => 53.8155,
                    'longitude' => -1.5703,
                    'id' => 'paf_111',
                ],
                [
                    'postcode' => 'LS6 3AA',
                    'post_town' => 'LEEDS',
                    'line_1' => '14 Cardigan Road',
                    'line_2' => '',
                    'line_3' => '',
                    'county' => 'West Yorkshire',
                    'latitude' => 53.8156,
                    'longitude' => -1.5704,
                    'id' => 'paf_112',
                ],
            ],
            'code' => 2000,
            'message' => 'Success',
        ];
    }

    public function test_a_postcode_returns_every_address_there(): void
    {
        Setting::set(PostcodeAddressService::SETTING_KEY, 'ak_test');
        Http::fake(['api.ideal-postcodes.co.uk/*' => Http::response($this->idealPostcodesFound())]);

        $response = $this->getJson('/api/v1/addresses/postcode?postcode=ls63aa');

        $response->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.line1', 'Flat 2')
            ->assertJsonPath('data.0.line2', '12 Cardigan Road')
            ->assertJsonPath('data.0.city', 'Leeds')
            ->assertJsonPath('data.0.county', 'West Yorkshire')
            ->assertJsonPath('data.0.postcode', 'LS6 3AA')
            ->assertJsonPath('data.0.address', 'Flat 2, 12 Cardigan Road, Leeds, LS6 3AA')
            ->assertJsonPath('data.1.line2', null);
        Http::assertSent(fn ($request) => str_contains($request->url(), '/v1/postcodes/LS6%203AA')
            && $request['api_key'] === 'ak_test');
    }

    public function test_the_same_postcode_is_only_paid_for_once_a_day(): void
    {
        Setting::set(PostcodeAddressService::SETTING_KEY, 'ak_test');
        Http::fake(['api.ideal-postcodes.co.uk/*' => Http::response($this->idealPostcodesFound())]);

        $this->getJson('/api/v1/addresses/postcode?postcode=LS6 3AA')->assertOk();
        $this->getJson('/api/v1/addresses/postcode?postcode=ls6 3aa')->assertOk();

        Http::assertSentCount(1);
    }

    public function test_an_unknown_postcode_is_a_404(): void
    {
        Setting::set(PostcodeAddressService::SETTING_KEY, 'ak_test');
        Http::fake(['api.ideal-postcodes.co.uk/*' => Http::response(
            ['code' => 4040, 'message' => 'Postcode not found', 'suggestions' => []],
            404,
        )]);

        $this->getJson('/api/v1/addresses/postcode?postcode=LS99 9ZZ')
            ->assertNotFound()
            ->assertJsonPath('message', "We couldn't find that postcode. Please check it.");
    }

    public function test_without_an_api_key_the_lookup_is_unavailable(): void
    {
        Http::fake();

        $this->getJson('/api/v1/addresses/postcode?postcode=LS6 3AA')->assertStatus(503);
        Http::assertNothingSent();
    }

    public function test_a_provider_error_such_as_no_credits_left_is_unavailable(): void
    {
        Setting::set(PostcodeAddressService::SETTING_KEY, 'ak_test');
        Http::fake(['api.ideal-postcodes.co.uk/*' => Http::response(
            ['code' => 4020, 'message' => 'Token balance depleted'],
            402,
        )]);

        $this->getJson('/api/v1/addresses/postcode?postcode=LS6 3AA')->assertStatus(503);
    }

    public function test_a_malformed_postcode_is_rejected_without_a_paid_call(): void
    {
        Setting::set(PostcodeAddressService::SETTING_KEY, 'ak_test');
        Http::fake();

        $this->getJson('/api/v1/addresses/postcode?postcode=hello')
            ->assertUnprocessable()
            ->assertJsonValidationErrors('postcode');
        Http::assertNothingSent();
    }
}
