<?php

namespace Tests\Feature\Api;

use App\Mail\PasswordResetCode;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Tests\TestCase;

class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    private function requestCode(string $email): ?string
    {
        $code = null;
        Mail::fake();
        $this->postJson('/api/v1/auth/forgot-password', ['email' => $email])->assertOk();
        Mail::assertSent(PasswordResetCode::class, function (PasswordResetCode $mail) use (&$code) {
            $code = $mail->code;

            return true;
        });

        return $code;
    }

    public function test_a_code_resets_the_password_and_signs_out_everywhere(): void
    {
        $user = User::factory()->create(['email' => 'rina@example.com']);
        $user->createToken('phone');
        $code = $this->requestCode('Rina@Example.com');

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => 'rina@example.com',
            'code' => $code,
            'password' => 'brand-new-pass',
            'password_confirmation' => 'brand-new-pass',
        ])->assertOk();

        $this->assertTrue(Hash::check('brand-new-pass', $user->fresh()->password));
        $this->assertSame(0, $user->tokens()->count());
        $this->postJson('/api/v1/auth/login', ['email' => 'rina@example.com', 'password' => 'brand-new-pass'])->assertOk();
    }

    public function test_an_unknown_email_gets_the_same_answer_and_no_mail(): void
    {
        Mail::fake();

        $this->postJson('/api/v1/auth/forgot-password', ['email' => 'nobody@example.com'])
            ->assertOk()
            ->assertJsonPath('message', 'If an account exists for that email, we have sent it a reset code.');
        Mail::assertNothingSent();
    }

    public function test_a_wrong_code_is_rejected_and_the_code_locks_after_five_tries(): void
    {
        $user = User::factory()->create(['email' => 'rina@example.com']);
        $code = $this->requestCode('rina@example.com');
        $wrong = $code === '111111' ? '222222' : '111111';
        $payload = fn (string $code) => [
            'email' => 'rina@example.com',
            'code' => $code,
            'password' => 'brand-new-pass',
            'password_confirmation' => 'brand-new-pass',
        ];

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/v1/auth/reset-password', $payload($wrong))
                ->assertUnprocessable()
                ->assertJsonValidationErrors('code');
        }

        // Even the right code no longer works.
        $this->postJson('/api/v1/auth/reset-password', $payload($code))->assertUnprocessable();
        $this->assertFalse(Hash::check('brand-new-pass', $user->fresh()->password));
    }

    public function test_an_expired_code_is_rejected(): void
    {
        User::factory()->create(['email' => 'rina@example.com']);
        $code = $this->requestCode('rina@example.com');

        $this->travel(31)->minutes();

        $this->postJson('/api/v1/auth/reset-password', [
            'email' => 'rina@example.com',
            'code' => $code,
            'password' => 'brand-new-pass',
            'password_confirmation' => 'brand-new-pass',
        ])->assertUnprocessable();
    }
}
