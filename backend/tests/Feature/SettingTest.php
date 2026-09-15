<?php

namespace Tests\Feature;

use App\Models\Setting;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class SettingTest extends TestCase
{
    use RefreshDatabase;

    public function test_get_returns_the_default_when_the_key_does_not_exist(): void
    {
        $this->assertNull(Setting::get('missing_key'));
        $this->assertSame('fallback', Setting::get('missing_key', 'fallback'));
    }

    public function test_set_then_get_round_trips_the_value(): void
    {
        Setting::set('anthropic_api_key', 'sk-ant-example-12345');

        $this->assertSame('sk-ant-example-12345', Setting::get('anthropic_api_key'));
    }

    public function test_set_is_stored_encrypted_at_rest(): void
    {
        Setting::set('anthropic_api_key', 'sk-ant-example-12345');

        $rawValue = DB::table('settings')->where('key', 'anthropic_api_key')->value('value');

        $this->assertNotSame('sk-ant-example-12345', $rawValue);
        $this->assertStringNotContainsString('sk-ant-example-12345', $rawValue);
    }

    public function test_set_on_an_existing_key_overwrites_rather_than_duplicating(): void
    {
        Setting::set('anthropic_api_key', 'first-value');
        Setting::set('anthropic_api_key', 'second-value');

        $this->assertSame('second-value', Setting::get('anthropic_api_key'));
        $this->assertDatabaseCount('settings', 1);
    }
}
