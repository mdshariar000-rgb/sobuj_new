<?php

namespace Tests\Feature\Filament;

use App\Filament\Pages\ManageSettings;
use App\Models\Setting;
use App\Models\User;
use App\Services\PostcodeAddressService;
use App\Support\MailSettings;
use App\Support\SocialSettings;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class ManageSettingsTest extends TestCase
{
    use RefreshDatabase;

    public function test_non_admin_cannot_access_the_settings_page(): void
    {
        $user = User::factory()->create(['is_admin' => false]);

        $this->actingAs($user)
            ->get(ManageSettings::getUrl())
            ->assertForbidden();
    }

    public function test_admin_can_access_the_settings_page(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);

        $this->actingAs($admin)
            ->get(ManageSettings::getUrl())
            ->assertSuccessful();
    }

    public function test_the_support_email_prefills_and_saves(): void
    {
        Setting::set('support_email', 'help@example.com');

        Livewire::actingAs(User::factory()->create(['is_admin' => true]))
            ->test(ManageSettings::class)
            ->assertFormSet(['support_email' => 'help@example.com'])
            ->fillForm(['support_email' => 'support@example.com'])
            ->call('save')
            ->assertHasNoFormErrors()
            ->assertFormSet(['support_email' => 'support@example.com']);

        $this->assertSame('support@example.com', Setting::get('support_email'));
    }

    public function test_the_page_no_longer_offers_gemini_or_stripe_settings(): void
    {
        $this->actingAs(User::factory()->create(['is_admin' => true]))
            ->get(ManageSettings::getUrl())
            ->assertOk()
            ->assertDontSee('Gemini')
            ->assertDontSee('Stripe');
    }

    public function test_the_postcode_lookup_key_saves_and_a_blank_field_keeps_it(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);

        Livewire::actingAs($admin)
            ->test(ManageSettings::class)
            ->assertFormSet(['ideal_postcodes_api_key' => null])
            ->fillForm(['ideal_postcodes_api_key' => 'ak_live_123'])
            ->call('save')
            ->assertHasNoFormErrors()
            // The key is never sent back to the browser.
            ->assertFormSet(['ideal_postcodes_api_key' => null]);
        $this->assertSame('ak_live_123', Setting::get(PostcodeAddressService::SETTING_KEY));

        Livewire::actingAs($admin)
            ->test(ManageSettings::class)
            ->fillForm(['support_email' => 'help@example.com'])
            ->call('save')
            ->assertHasNoFormErrors();
        $this->assertSame('ak_live_123', Setting::get(PostcodeAddressService::SETTING_KEY));
    }

    public function test_smtp_settings_save_and_a_blank_password_keeps_the_saved_one(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);

        Livewire::actingAs($admin)
            ->test(ManageSettings::class)
            ->fillForm([
                'mail_host' => 'smtp.example.com',
                'mail_port' => '465',
                'mail_encryption' => 'ssl',
                'mail_username' => 'hello@example.com',
                'mail_password' => 'app-password',
                'mail_from_address' => 'hello@example.com',
                'mail_from_name' => 'Shobuj',
            ])
            ->call('save')
            ->assertHasNoFormErrors()
            ->assertFormSet(['mail_host' => 'smtp.example.com', 'mail_password' => null]);

        Livewire::actingAs($admin)
            ->test(ManageSettings::class)
            ->fillForm(['mail_from_name' => 'Shobuj App'])
            ->call('save')
            ->assertHasNoFormErrors();

        $this->assertSame('app-password', Setting::get('mail_password'));
        $this->assertSame('Shobuj App', Setting::get('mail_from_name'));
    }

    public function test_a_host_needs_a_port_username_and_from_address(): void
    {
        Livewire::actingAs(User::factory()->create(['is_admin' => true]))
            ->test(ManageSettings::class)
            ->fillForm(['mail_host' => 'smtp.example.com'])
            ->call('save')
            ->assertHasFormErrors(['mail_port', 'mail_username', 'mail_from_address']);
    }

    public function test_saved_smtp_settings_are_what_mail_is_sent_with(): void
    {
        foreach ([
            'mail_host' => 'smtp.example.com',
            'mail_port' => '465',
            'mail_encryption' => 'ssl',
            'mail_username' => 'hello@example.com',
            'mail_password' => 'app-password',
            'mail_from_address' => 'hello@example.com',
            'mail_from_name' => 'Shobuj',
        ] as $key => $value) {
            Setting::set($key, $value);
        }

        MailSettings::apply();

        $this->assertSame('smtp', config('mail.default'));
        $this->assertSame('smtp.example.com', config('mail.mailers.smtp.host'));
        $this->assertSame(465, config('mail.mailers.smtp.port'));
        $this->assertSame('smtps', config('mail.mailers.smtp.scheme'));
        $this->assertSame('app-password', config('mail.mailers.smtp.password'));
        $this->assertSame('Shobuj', config('mail.from.name'));
    }

    public function test_without_a_saved_host_the_env_settings_stay(): void
    {
        config(['mail.default' => 'log', 'mail.mailers.smtp.host' => 'env-host']);
        Setting::set('mail_from_name', 'Ignored');

        MailSettings::apply();

        $this->assertSame('log', config('mail.default'));
        $this->assertSame('env-host', config('mail.mailers.smtp.host'));
    }

    public function test_the_test_email_button_sends_one(): void
    {
        // In-memory transport, so the real message can be checked.
        config(['mail.default' => 'array', 'mail.from.name' => 'Shobuj']);
        $admin = User::factory()->create(['is_admin' => true]);

        Livewire::actingAs($admin)
            ->test(ManageSettings::class)
            ->callAction('sendTestEmail', ['to' => 'check@example.com'])
            ->assertHasNoActionErrors()
            ->assertNotified('Test email sent to check@example.com');

        $messages = app('mail.manager')->mailer('array')->getSymfonyTransport()->messages();
        $this->assertCount(1, $messages);
        $email = $messages->first()->getOriginalMessage();
        $this->assertSame('check@example.com', $email->getTo()[0]->getAddress());
        $this->assertSame('Test email from Shobuj', $email->getSubject());
    }

    public function test_social_sign_in_settings_save_and_the_apple_key_is_kept_secret(): void
    {
        $admin = User::factory()->create(['is_admin' => true]);
        $key = openssl_pkey_new(['curve_name' => 'prime256v1', 'private_key_type' => OPENSSL_KEYTYPE_EC]);
        openssl_pkey_export($key, $p8);

        Livewire::actingAs($admin)
            ->test(ManageSettings::class)
            ->assertFormSet([SocialSettings::GOOGLE_ENABLED => false, SocialSettings::APPLE_ENABLED => false])
            ->fillForm([
                SocialSettings::GOOGLE_ENABLED => true,
                SocialSettings::GOOGLE_IOS_CLIENT_ID => 'ios.apps.googleusercontent.com',
                SocialSettings::GOOGLE_SERVER_CLIENT_ID => 'web.apps.googleusercontent.com',
                SocialSettings::APPLE_ENABLED => true,
                SocialSettings::APPLE_TEAM_ID => 'XCGZVG9PT7',
                SocialSettings::APPLE_KEY_ID => 'ABC123DEFG',
                SocialSettings::APPLE_PRIVATE_KEY => $p8,
            ])
            ->call('save')
            ->assertHasNoFormErrors()
            ->assertFormSet([SocialSettings::APPLE_PRIVATE_KEY => null, SocialSettings::GOOGLE_ENABLED => true]);

        $settings = SocialSettings::all();
        $this->assertTrue(SocialSettings::googleEnabled($settings));
        $this->assertTrue(SocialSettings::appleEnabled($settings));
        $this->assertTrue(SocialSettings::appleKeyConfigured($settings));

        // Saving again with the key field blank keeps it.
        Livewire::actingAs($admin)->test(ManageSettings::class)->call('save')->assertHasNoFormErrors();
        $this->assertSame(trim($p8), Setting::get(SocialSettings::APPLE_PRIVATE_KEY));
    }

    public function test_a_broken_apple_key_is_rejected(): void
    {
        Livewire::actingAs(User::factory()->create(['is_admin' => true]))
            ->test(ManageSettings::class)
            ->fillForm([SocialSettings::APPLE_PRIVATE_KEY => 'not a key'])
            ->call('save')
            ->assertHasFormErrors([SocialSettings::APPLE_PRIVATE_KEY]);
    }
}
