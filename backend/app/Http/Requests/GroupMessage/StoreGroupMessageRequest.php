<?php

namespace App\Http\Requests\GroupMessage;

use App\Models\GroupMessage;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Http\UploadedFile;
use Illuminate\Validation\Rule;
use Illuminate\Validation\Validator;

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
            // A message needs at least a body or a photo — none is individually
            // required so a photo-only message (no caption) is valid. `images[]`
            // carries up to MAX_IMAGES photos; the single `image` field is what
            // older app builds still send.
            'body' => ['required_without_all:image,images', 'nullable', 'string', 'max:2000'],
            'image' => ['nullable', 'image', 'mimes:jpeg,png,webp', 'max:8192'],
            'images' => ['nullable', 'array', 'max:'.GroupMessage::MAX_IMAGES],
            'images.*' => ['image', 'mimes:jpeg,png,webp', 'max:8192'],
            // Only a message from this same thread can be quoted.
            'reply_to_id' => [
                'nullable',
                'integer',
                Rule::exists('group_messages', 'id')->where('group_id', $this->route('group')?->id),
            ],
        ];
    }

    /**
     * Every uploaded photo, in the order sent — the legacy single `image`
     * first, then `images[]`.
     *
     * @return list<UploadedFile>
     */
    public function uploadedImages(): array
    {
        return array_values(array_filter([
            $this->file('image'),
            ...($this->file('images') ?? []),
        ]));
    }

    /**
     * @return array<int, \Closure>
     */
    public function after(): array
    {
        return [
            function (Validator $validator) {
                if (count($this->uploadedImages()) > GroupMessage::MAX_IMAGES) {
                    $validator->errors()->add('images', 'You can send at most '.GroupMessage::MAX_IMAGES.' photos in one message.');
                }
            },
        ];
    }
}
