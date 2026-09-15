<?php

namespace Tests\Feature\Filament;

use App\Models\User;
use Filament\Pages\Auth\Login;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class LoginTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_can_log_in_through_the_actual_livewire_login_form(): void
    {
        $admin = User::factory()->create([
            'email' => 'admin@shobuj.test',
            'password' => 'ChangeMe123',
            'is_admin' => true,
        ]);

        Livewire::test(Login::class)
            ->fillForm([
                'email' => 'admin@shobuj.test',
                'password' => 'ChangeMe123',
            ])
            ->call('authenticate')
            ->assertHasNoFormErrors();

        $this->assertAuthenticatedAs($admin);
    }

    public function test_non_admin_is_rejected_at_login(): void
    {
        User::factory()->create([
            'email' => 'nobody@shobuj.test',
            'password' => 'ChangeMe123',
            'is_admin' => false,
        ]);

        Livewire::test(Login::class)
            ->fillForm([
                'email' => 'nobody@shobuj.test',
                'password' => 'ChangeMe123',
            ])
            ->call('authenticate')
            ->assertHasFormErrors();

        $this->assertGuest();
    }
}
