<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Validation\ValidationException;

class BlockController extends Controller
{
    private const PER_PAGE = 50;

    /**
     * The accounts the caller has blocked, most recently blocked first — the
     * "Blocked users" management screen.
     */
    public function index(Request $request): AnonymousResourceCollection
    {
        $blocked = $request->user()
            ->blockedUsers()
            ->orderByPivot('created_at', 'desc')
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return UserResource::collection($blocked);
    }

    /**
     * Idempotent — blocking an already-blocked user is a no-op.
     */
    public function store(Request $request, User $user): JsonResponse
    {
        if ($user->is($request->user())) {
            throw ValidationException::withMessages([
                'user' => ['You cannot block yourself.'],
            ]);
        }

        $request->user()->blockedUsers()->syncWithoutDetaching([
            $user->id => ['created_at' => now()],
        ]);

        return response()->json(['message' => 'User blocked.']);
    }

    public function destroy(Request $request, User $user): JsonResponse
    {
        $request->user()->blockedUsers()->detach($user->id);

        return response()->json(['message' => 'User unblocked.']);
    }
}
