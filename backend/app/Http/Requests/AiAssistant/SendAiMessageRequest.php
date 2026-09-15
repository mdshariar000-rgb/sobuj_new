<?php

namespace App\Http\Requests\AiAssistant;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class SendAiMessageRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * Either a body or a photo (or both) must be present — a bare photo
     * upload with no caption is a valid "diagnose this" request.
     *
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'conversation_id' => ['nullable', 'integer', Rule::exists('ai_conversations', 'id')->where('user_id', $this->user()?->id)],
            'body' => ['nullable', 'required_without:photo', 'string', 'max:4000'],
            'photo' => ['nullable', 'required_without:body', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
        ];
    }
}
