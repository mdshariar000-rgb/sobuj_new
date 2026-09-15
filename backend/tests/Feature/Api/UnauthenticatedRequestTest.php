<?php

namespace Tests\Feature\Api;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UnauthenticatedRequestTest extends TestCase
{
    use RefreshDatabase;

    public function test_protected_api_route_returns_401_even_without_an_accept_header(): void
    {
        // Deliberately not using getJson()/postJson() here — those set
        // Accept: application/json automatically, which was masking this bug.
        $response = $this->get('/api/v1/listings/nearby?latitude=23.7&longitude=90.4');

        $response->assertUnauthorized();
    }
}
