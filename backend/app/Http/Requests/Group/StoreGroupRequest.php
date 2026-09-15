<?php

namespace App\Http\Requests\Group;

use App\Enums\GroupVisibility;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StoreGroupRequest extends FormRequest
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
            'name' => ['required', 'string', 'max:255'],
            'slug' => ['required', 'string', 'max:255', 'alpha_dash', Rule::unique('groups', 'slug')],
            'description' => ['nullable', 'string', 'max:2000'],
            'category' => ['nullable', Rule::exists('group_categories', 'name')],
            'visibility' => ['sometimes', Rule::enum(GroupVisibility::class)],
            'cover_image' => ['nullable', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
            'avatar' => ['nullable', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
        ];
    }
}
