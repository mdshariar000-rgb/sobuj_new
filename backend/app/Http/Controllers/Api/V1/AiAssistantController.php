<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\AiMessageRole;
use App\Http\Controllers\Controller;
use App\Http\Requests\AiAssistant\SendAiMessageRequest;
use App\Http\Resources\AiConversationResource;
use App\Models\AiConversation;
use App\Services\AgriAssistantService;
use App\Services\ImageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class AiAssistantController extends Controller
{
    private const PER_PAGE = 20;

    public function index(Request $request): AnonymousResourceCollection
    {
        $this->authorizeAgriAiAccess($request);

        $conversations = $request->user()
            ->aiConversations()
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return AiConversationResource::collection($conversations);
    }

    public function show(Request $request, AiConversation $conversation): AiConversationResource
    {
        $this->authorizeAgriAiAccess($request);
        $this->authorize('view', $conversation);

        $conversation->load(['messages' => fn ($query) => $query->oldest()]);

        return new AiConversationResource($conversation);
    }

    /**
     * Sends a user message (text and/or a leaf photo) to a conversation —
     * creating one first if conversation_id is omitted — then synchronously
     * calls Gemini and persists+returns its reply alongside it.
     */
    public function sendMessage(
        SendAiMessageRequest $request,
        AgriAssistantService $agriAssistant,
        ImageService $imageService,
    ): JsonResponse {
        $this->authorizeAgriAiAccess($request);

        $data = $request->validated();
        $user = $request->user();

        if (! empty($data['conversation_id'])) {
            $conversation = AiConversation::query()->findOrFail($data['conversation_id']);
            $this->authorize('sendMessage', $conversation);
        } else {
            $conversation = new AiConversation;
            $conversation->user_id = $user->id;
            $conversation->save();
        }

        $imagePath = $request->hasFile('photo')
            ? $imageService->store($request->file('photo'), 'ai-uploads/'.$conversation->id)
            : null;

        $conversation->messages()->create([
            'role' => AiMessageRole::User,
            'body' => $data['body'] ?? null,
            'image_path' => $imagePath,
        ]);

        $replyText = $agriAssistant->reply($conversation);

        $conversation->messages()->create([
            'role' => AiMessageRole::Assistant,
            'body' => $replyText,
        ]);

        $conversation->load(['messages' => fn ($query) => $query->oldest()]);

        return (new AiConversationResource($conversation))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * The Agri-AI Assistant is a paid feature end to end — reading past
     * conversations included, not just sending new messages — per the
     * product decision that there is no free tier at all. See
     * User::hasAgriAiAccess() / SubscriptionController.
     */
    private function authorizeAgriAiAccess(Request $request): void
    {
        abort_unless(
            $request->user()->hasAgriAiAccess(),
            403,
            'An active Agri-AI subscription is required.',
        );
    }
}
