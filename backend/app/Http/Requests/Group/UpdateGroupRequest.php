<?php

namespace App\Http\Requests\Group;

use App\Enums\GroupVisibility;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateGroupRequest extends FormRequest
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
            'name' => ['sometimes', 'string', 'max:255'],
            'slug' => ['sometimes', 'string', 'max:255', 'alpha_dash', Rule::unique('groups', 'slug')->ignore($this->route('group'))],
            'description' => ['nullable', 'string', 'max:2000'],
            'category' => ['nullable', Rule::exists('group_categories', 'name')],
            'visibility' => ['sometimes', Rule::enum(GroupVisibility::class)],
            'cover_image' => ['nullable', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
            'avatar' => ['nullable', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
            // Sending an empty string unpins; omitting the key leaves the
            // current pin untouched — see GroupController::update().
            'pinned_message' => ['sometimes', 'nullable', 'string', 'max:500'],
        ];
    }
}
