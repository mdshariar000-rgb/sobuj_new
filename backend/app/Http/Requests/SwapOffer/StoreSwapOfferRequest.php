<?php

namespace App\Http\Requests\SwapOffer;

use Illuminate\Foundation\Http\FormRequest;

class StoreSwapOfferRequest extends FormRequest
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
            'offer_details' => ['nullable', 'array'],
            'offer_details.offered_listing_id' => ['nullable', 'integer', 'exists:listings,id'],
            'offer_details.note' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
