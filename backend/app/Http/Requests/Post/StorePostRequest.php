<?php

namespace App\Http\Requests\Post;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class StorePostRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * group_id is nullable/omittable: null (or absent) posts to the general
     * Home Feed, set posts into that group's discussion thread. Group
     * membership is enforced in the controller, not here, since it needs a
     * DB lookup against the authenticated user rather than a static rule.
     *
     * category is nullable/omittable too — defaults to General in the
     * controller. Validated against the admin-managed post_categories list
     * by name (see PostCategory), not a fixed set — an admin can add or
     * rename categories from the Filament panel at any time. Group
     * discussion posts have no use for Disease Alert/Harvest tabs (those are
     * Home Feed-only filters), but the rule itself doesn't need to
     * special-case that; nothing reads category for group posts.
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'group_id' => ['nullable', 'integer', 'exists:groups,id'],
            'body' => ['required', 'string', 'max:5000'],
            'category' => ['nullable', 'string', Rule::exists('post_categories', 'name')],
            'image' => ['nullable', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
        ];
    }
}
