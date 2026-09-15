<?php

namespace App\Http\Requests\Comment;

use Illuminate\Foundation\Http\FormRequest;

class StoreCommentRequest extends FormRequest
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
            'body' => ['required', 'string', 'max:2000'],
            // The specific comment being replied to (top-level or another
            // reply) — the controller normalizes this to the thread's
            // top-level parent_id and records who's actually being
            // addressed. Existence within this post is checked there too,
            // since that needs the route-bound Post.
            'reply_to_comment_id' => ['nullable', 'integer'],
        ];
    }
}
