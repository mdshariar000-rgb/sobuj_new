<?php

namespace App\Http\Requests\SwapOffer;

use App\Enums\SwapOfferStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateSwapOfferStatusRequest extends FormRequest
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
            'status' => ['required', Rule::enum(SwapOfferStatus::class)],

            // Only meaningful when status is being set to `countered` — the new terms
            // being proposed. Actual role/transition validity is enforced by
            // SwapOfferPolicy::respond(), not here.
            'offer_details' => ['nullable', 'array'],
            'offer_details.offered_listing_id' => ['nullable', 'integer', 'exists:listings,id'],
            'offer_details.note' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
