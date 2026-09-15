<?php

namespace App\Http\Requests\Listing;

use App\Enums\ListingCondition;
use App\Enums\ListingType;
use App\Enums\TransactionType;
use App\Rules\NotBannedSpecies;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreListingRequest extends FormRequest
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
            'title' => ['required', 'string', 'max:255', new NotBannedSpecies],
            'variety' => ['nullable', 'string', 'max:255', new NotBannedSpecies],
            'description' => ['nullable', 'string', 'max:2000'],
            'condition' => ['nullable', Rule::enum(ListingCondition::class)],
            'listing_type' => ['required', Rule::enum(ListingType::class)],
            'transaction_type' => ['required', Rule::enum(TransactionType::class)],

            // Mirrors chk_listings_price_required_for_paid_transaction at the DB layer.
            'price' => [
                Rule::requiredIf(fn () => in_array($this->input('transaction_type'), ['sell', 'swap_or_cash'], true)),
                'nullable',
                'numeric',
                'min:0',
                'max:99999.99',
            ],

            'looking_for' => ['nullable', 'string', 'max:1000'],
            'handover_note' => ['nullable', 'string', 'max:500'],

            // Optional: defaults to the poster's own location when omitted (see
            // ListingController::resolveLocation()). Both or neither.
            'latitude' => ['nullable', 'required_with:longitude', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'required_with:latitude', 'numeric', 'between:-180,180'],

            'photos' => ['nullable', 'array', 'max:6'],
            'photos.*' => ['image', 'mimes:jpeg,png,webp', 'max:8192'],
        ];
    }
}
