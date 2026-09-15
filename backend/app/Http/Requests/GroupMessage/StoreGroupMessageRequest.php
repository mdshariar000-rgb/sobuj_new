<?php

namespace App\Http\Requests\GroupMessage;

use Illuminate\Foundation\Http\FormRequest;

class StoreGroupMessageRequest extends FormRequest
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
            // A message needs at least a body or an image — neither is individually
            // required so an image-only message (no caption) is valid.
            'body' => ['required_without:image', 'nullable', 'string', 'max:2000'],
            'image' => ['required_without:body', 'nullable', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
        ];
    }
}
