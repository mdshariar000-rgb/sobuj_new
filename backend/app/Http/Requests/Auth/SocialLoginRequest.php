<?php

namespace App\Http\Requests\Auth;

use App\Enums\ExperienceLevel;
use App\Enums\GrowingSetup;
use App\Support\Interests;
use App\Support\UkAddress;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * "Sign in with Google / Apple". The token alone signs in an existing
 * account. A new account also needs what sign-up always asks for — the
 * address and its map location — so the app sends those on a second call
 * after the server answers `needs_signup`.
 */
class SocialLoginRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    protected function prepareForValidation(): void
    {
        if ($this->has('address_postcode')) {
            $this->merge(['address_postcode' => UkAddress::normalisePostcode($this->input('address_postcode'))]);
        }
    }

    public function rules(): array
    {
        $signingUp = $this->filled('address_postcode');

        return [
            'provider' => ['required', Rule::in(['google', 'apple'])],
            'id_token' => ['required', 'string', 'max:8000'],
            'nonce' => ['nullable', 'string', 'max:255'],
            'device_name' => ['nullable', 'string', 'max:255'],
            // Apple only shares the name on the very first sign-in.
            'name' => [$signingUp ? 'required' : 'nullable', 'string', 'max:255'],
            ...($signingUp ? [
                ...UkAddress::rules(required: true),
                'latitude' => ['required', 'numeric', 'between:-90,90'],
                'longitude' => ['required', 'numeric', 'between:-180,180'],
                'location_label' => ['nullable', 'string', 'max:255'],
                'experience_level' => ['nullable', Rule::enum(ExperienceLevel::class)],
                'growing_setup' => ['nullable', Rule::enum(GrowingSetup::class)],
                'growing_interests' => ['nullable', 'array', 'max:10'],
                'growing_interests.*' => ['string', Rule::in(Interests::ALL)],
            ] : []),
        ];
    }
}
