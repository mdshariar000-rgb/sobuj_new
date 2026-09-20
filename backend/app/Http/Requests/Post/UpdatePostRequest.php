<?php

namespace App\Http\Requests\Post;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdatePostRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * group_id/author are never editable here — only the content an author
     * can genuinely change after posting. Same category rule as
     * StorePostRequest.
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'body' => ['sometimes', 'string', 'max:5000'],
            'category' => ['nullable', 'string', Rule::exists('post_categories', 'name')],
            'image' => ['nullable', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
            'remove_image' => ['nullable', 'boolean'],
        ];
    }
}
