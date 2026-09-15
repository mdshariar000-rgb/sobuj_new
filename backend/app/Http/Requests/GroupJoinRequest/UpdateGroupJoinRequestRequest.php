<?php

namespace App\Http\Requests\GroupJoinRequest;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateGroupJoinRequestRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * A distinct field from the group_join_requests.status column — an
     * "approve" decision never becomes a stored status, it deletes the row
     * and creates a real group_members row instead. See
     * GroupJoinRequestController::update().
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'decision' => ['required', Rule::in(['approve', 'reject'])],
        ];
    }
}
