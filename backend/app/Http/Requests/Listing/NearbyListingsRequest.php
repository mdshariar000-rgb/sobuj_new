<?php

namespace App\Http\Requests\Listing;

use App\Enums\ListingType;
use App\Enums\TransactionType;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class NearbyListingsRequest extends FormRequest
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
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'radius_km' => ['nullable', 'numeric', 'between:1,50'],

            // "category" is the public-facing name for the listing_type column.
            'category' => ['nullable', Rule::enum(ListingType::class)],
            'transaction_type' => ['nullable', Rule::enum(TransactionType::class)],

            'per_page' => ['nullable', 'integer', 'between:1,50'],

            // Defaults to nearest-first (Listing::scopeNearby()'s own ordering).
            'sort' => ['nullable', 'in:nearest,newest'],

            // Free-text match against title/variety/looking_for — see
            // Listing::scopeSearch(). Kept simple (LIKE-based) since it only needs to
            // filter an already geo/status/type-narrowed result set, not search the
            // whole table.
            'q' => ['nullable', 'string', 'max:255'],
        ];
    }
}
