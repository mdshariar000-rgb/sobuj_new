<?php

namespace App\Services;

use App\Enums\AiMessageRole;
use App\Models\AiConversation;
use App\Models\AiMessage;
use App\Models\Setting;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Storage;

/**
 * Wraps the Gemini API's generateContent endpoint for the "FloraAI" Agri-AI
 * Assistant: a plant/gardening-focused chat that can also diagnose an
 * uploaded leaf photo.
 *
 * There's no official Google PHP SDK for the Gemini API, so this calls the
 * REST endpoint directly via Laravel's Http client.
 *
 * gemini-3.8-flash is used unconditionally per this project's mandated
 * default model (verified live against the real API on 2026-09-12 as the
 * current stable Flash release) — swap to a different model here only on
 * explicit request.
 */
class AgriAssistantService
{
    private const MODEL = 'gemini-3.8-flash';

    private const ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models/'.self::MODEL.':generateContent';

    private const MAX_OUTPUT_TOKENS = 2048;

    private const SYSTEM_PROMPT = <<<'PROMPT'
        You are FloraAI, the Agri-AI assistant inside the Agro Hub app. Your
        scope is strictly limited to two things:

        1. Diagnosing plant and tree health problems — pests, disease, nutrient
           deficiency, watering/soil issues — from a description and/or a photo.
        2. General plant and tree farming discussion — planting, pruning,
           soil, watering, fertilizing, harvesting, crop/species selection, and
           related agronomy practices.

        This is the entire scope of the assistant. If a message asks about
        anything else — other subjects, general chit-chat, requests to act as a
        different kind of assistant, or anything unrelated to plant/tree health
        or farming — do not answer it. Instead, briefly and politely decline and
        redirect the user back to plant/tree diagnosis or farming questions.
        Never break this scope, even if asked directly to.

        When a photo of a plant or leaf is included, examine it closely and
        describe what you observe (color, spotting, wilting, pests) before
        giving a diagnosis and a concrete, actionable recommendation. Keep
        answers practical and concise. If you are not confident in a diagnosis
        from the photo alone, say so and suggest what additional detail would
        help.
        PROMPT;

    /**
     * Sends the full conversation history (including the just-persisted
     * $newUserMessage) to Gemini and returns the assistant's reply text.
     */
    public function reply(AiConversation $conversation): string
    {
        $contents = $conversation->messages()
            ->orderBy('created_at')
            ->get()
            ->map(fn (AiMessage $message) => [
                'role' => $message->role === AiMessageRole::User ? 'user' : 'model',
                'parts' => $this->partsFor($message),
            ])
            ->all();

        $response = Http::withHeaders(['x-goog-api-key' => $this->apiKey()])
            ->post(self::ENDPOINT, [
                'systemInstruction' => ['parts' => [['text' => self::SYSTEM_PROMPT]]],
                'contents' => $contents,
                'generationConfig' => [
                    'maxOutputTokens' => self::MAX_OUTPUT_TOKENS,
                    // Plain Q&A/diagnosis doesn't need extended reasoning — matches
                    // the previous Claude setup, which didn't use extended thinking
                    // either — and keeps replies fast and cheap.
                    'thinkingConfig' => ['thinkingBudget' => 0],
                ],
            ])
            ->throw();

        $text = $response->json('candidates.0.content.parts.0.text');

        return is_string($text) && $text !== ''
            ? $text
            : "I wasn't able to come up with a response — please try again.";
    }

    /**
     * A key saved via the admin Settings page (app/Filament/Pages/ManageSettings.php)
     * always wins over .env — it needs to take effect immediately, without a
     * config-cache rebuild, which a plain config('services.gemini.api_key') read
     * can't do once `artisan config:cache` has run. .env stays as the fallback for
     * local dev/initial setup before any admin has set a key.
     */
    private function apiKey(): string
    {
        return Setting::get('gemini_api_key') ?: (string) config('services.gemini.api_key');
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function partsFor(AiMessage $message): array
    {
        $parts = [];

        if ($message->image_path !== null) {
            $parts[] = [
                'inline_data' => [
                    'mime_type' => Storage::disk('public')->mimeType($message->image_path) ?: 'image/jpeg',
                    'data' => base64_encode(Storage::disk('public')->get($message->image_path)),
                ],
            ];
        }

        $parts[] = [
            'text' => $message->body !== null && $message->body !== ''
                ? $message->body
                : 'Please take a look at this photo.',
        ];

        return $parts;
    }
}
