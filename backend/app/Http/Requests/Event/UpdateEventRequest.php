<?php

namespace App\Http\Requests\Event;

use App\Enums\EventFormat;
use App\Enums\EventStatus;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

class UpdateEventRequest extends FormRequest
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
            'title' => ['sometimes', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:5000'],
            'format' => ['sometimes', Rule::enum(EventFormat::class)],
            'category' => ['nullable', 'string', Rule::exists('event_categories', 'name')],
            'cover_image' => ['nullable', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
            'location' => ['nullable', 'string', 'max:255'],
            'starts_at' => ['sometimes', 'date'],
            'ends_at' => ['nullable', 'date', 'after:starts_at'],
            'capacity' => ['nullable', 'integer', 'min:1'],
            // Shown on the event; paid at the door, not through the app.
            'registration_fee' => ['nullable', 'numeric', 'min:0', 'max:99999'],
            // Other dates the host is considering, besides starts_at.
            'proposed_dates' => ['nullable', 'array', 'max:10'],
            'proposed_dates.*' => ['date'],
            'status' => ['sometimes', Rule::enum(EventStatus::class)],
        ];
    }
}
