<?php

namespace Tests\Feature\Api;

use App\Models\SowingGuideMonth;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SowingGuideTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_returns_all_twelve_months_in_order(): void
    {
        Sanctum::actingAs(User::factory()->create());

        $response = $this->getJson('/api/v1/sowing-guide')->assertOk();

        $this->assertSame(range(1, 12), array_column($response->json('data'), 'month'));
        $response->assertJsonPath('data.9.outdoors', ['Garlic', 'Broad beans', 'Hardy peas']);
        $response->assertJsonPath('data.9.under_cover', ['Sweet peas', 'Microgreens']);
    }

    public function test_admin_edits_show_up_in_the_api(): void
    {
        Sanctum::actingAs(User::factory()->create());

        SowingGuideMonth::query()->where('month', 3)->firstOrFail()
            ->update(['outdoors' => ['Potatoes'], 'under_cover' => []]);

        $this->getJson('/api/v1/sowing-guide')
            ->assertJsonPath('data.2.outdoors', ['Potatoes'])
            ->assertJsonPath('data.2.under_cover', []);
    }

    public function test_it_requires_authentication(): void
    {
        $this->getJson('/api/v1/sowing-guide')->assertUnauthorized();
    }
}
