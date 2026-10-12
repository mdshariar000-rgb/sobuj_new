<?php

namespace App\Http\Requests\Auth;

use App\Enums\ExperienceLevel;
use App\Enums\GrowingSetup;
use App\Support\UkAddress;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateProfileRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Multipart/form-data has no real boolean type — a raw Dart/JS `bool`
     * stringifies to the literal words "true"/"false", which Laravel's
     * `boolean` rule rejects (it only accepts 1/0/"1"/"0"). Normalizing here
     * means any client's spelling of a boolean works, rather than relying on
     * every client remembering to send "1"/"0" specifically.
     */
    protected function prepareForValidation(): void
    {
        if ($this->has('address_postcode')) {
            $this->merge(['address_postcode' => UkAddress::normalisePostcode($this->input('address_postcode'))]);
        }

        if ($this->has('show_handover_radius')) {
            $this->merge([
                'show_handover_radius' => filter_var(
                    $this->input('show_handover_radius'),
                    FILTER_VALIDATE_BOOLEAN,
                ),
            ]);
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'name' => ['sometimes', 'required', 'string', 'max:255'],

            'username' => [
                'sometimes',
                'nullable',
                'string',
                'max:30',
                'regex:/^[a-zA-Z0-9_]+$/',
                Rule::unique('users', 'username')->ignore($this->user()->id),
            ],

            'bio' => ['sometimes', 'nullable', 'string', 'max:300'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
            'location_label' => ['sometimes', 'nullable', 'string', 'max:255'],

            ...UkAddress::rules(required: false),
            // A new address moves the account's map location to its postcode.
            'latitude' => ['required_with:longitude', 'numeric', 'between:-90,90'],
            'longitude' => ['required_with:latitude', 'numeric', 'between:-180,180'],

            'growing_interests' => ['sometimes', 'nullable', 'array', 'max:10'],
            'growing_interests.*' => ['string', 'max:40'],

            'show_handover_radius' => ['sometimes', 'boolean'],

            'experience_level' => ['sometimes', 'nullable', Rule::enum(ExperienceLevel::class)],
            'growing_setup' => ['sometimes', 'nullable', Rule::enum(GrowingSetup::class)],

            'avatar' => ['sometimes', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
            'cover_photo' => ['sometimes', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
        ];
    }
}
