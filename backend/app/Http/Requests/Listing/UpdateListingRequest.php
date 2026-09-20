<?php

namespace App\Http\Requests\Listing;

use App\Enums\ListingCondition;
use App\Enums\ListingStatus;
use App\Enums\TransactionType;
use App\Rules\NotBannedSpecies;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateListingRequest extends FormRequest
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
            'title' => ['sometimes', 'required', 'string', 'max:255', new NotBannedSpecies],
            'variety' => ['sometimes', 'nullable', 'string', 'max:255', new NotBannedSpecies],
            'description' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'condition' => ['sometimes', 'nullable', Rule::enum(ListingCondition::class)],
            'listing_type' => ['sometimes', Rule::exists('listing_categories', 'name')],
            'transaction_type' => ['sometimes', Rule::enum(TransactionType::class)],

            'price' => [
                Rule::requiredIf(fn () => in_array(
                    $this->input('transaction_type', $this->route('listing')?->transaction_type?->value),
                    ['sell', 'swap_or_cash'],
                    true,
                )),
                'nullable',
                'numeric',
                'min:0',
                'max:99999.99',
            ],

            'looking_for' => ['sometimes', 'nullable', 'string', 'max:1000'],
            'handover_note' => ['sometimes', 'nullable', 'string', 'max:500'],
            'status' => ['sometimes', Rule::enum(ListingStatus::class)],

            'latitude' => ['nullable', 'required_with:longitude', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'required_with:latitude', 'numeric', 'between:-180,180'],

            'photos' => ['nullable', 'array', 'max:6'],
            'photos.*' => ['image', 'mimes:jpeg,png,webp', 'max:8192'],
        ];
    }
}
