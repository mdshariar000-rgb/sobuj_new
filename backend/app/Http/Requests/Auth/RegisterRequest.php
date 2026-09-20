<?php

namespace App\Http\Requests\Auth;

use App\Enums\ExperienceLevel;
use App\Enums\GrowingSetup;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Rules\Password;

class RegisterRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', Password::defaults()],

            // Mandatory: users/base_location & fuzzy_location are NOT NULL (required by
            // the SPATIAL index — see the users migration), and this is a hyper-local
            // app where an account with no location can't discover or be discovered.
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],

            // Free-text label the user types themselves (e.g. "Dhanmondi, Dhaka") —
            // separate from the required lat/lng point above, same field
            // UpdateProfileRequest accepts post-registration (see User::location_label).
            'location_label' => ['nullable', 'string', 'max:255'],

            'experience_level' => ['nullable', Rule::enum(ExperienceLevel::class)],
            'growing_setup' => ['nullable', Rule::enum(GrowingSetup::class)],

            'device_name' => ['nullable', 'string', 'max:255'],
        ];
    }
}
