<?php

namespace App\Http\Requests\Post;

use Illuminate\Foundation\Http\FormRequest;

class StorePostRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Group membership is enforced in the controller, not here, since it
     * needs a lookup against the signed-in user.
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            // Posts live in groups — there's no personal timeline.
            'group_id' => ['required', 'integer', 'exists:groups,id'],
            'body' => ['required', 'string', 'max:5000'],
            'image' => ['nullable', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
        ];
    }
}
