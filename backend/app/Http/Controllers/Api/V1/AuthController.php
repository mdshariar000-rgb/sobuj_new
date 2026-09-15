<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Requests\Auth\UpdateProfileRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\ImageService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * Register a new account. Location is mandatory — see RegisterRequest.
     */
    public function register(RegisterRequest $request): JsonResponse
    {
        $data = $request->validated();

        $user = DB::transaction(function () use ($data): User {
            $user = new User([
                'name' => $data['name'],
                'email' => $data['email'],
                'password' => $data['password'],
                'experience_level' => $data['experience_level'] ?? null,
                'growing_setup' => $data['growing_setup'] ?? null,
            ]);

            $user->setLocation((float) $data['latitude'], (float) $data['longitude']);
            $user->save();

            return $user;
        });

        $token = $user->createToken($data['device_name'] ?? 'mobile')->plainTextToken;

        return (new UserResource($user))->asSelf()
            ->additional(['token' => $token, 'token_type' => 'Bearer'])
            ->response()
            ->setStatusCode(201);
    }

    /**
     * Issue a new API token for an existing account. Does not revoke tokens already
     * issued to other devices, so a user can stay signed in on more than one device.
     */
    public function login(LoginRequest $request): JsonResponse
    {
        $data = $request->validated();

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        if ($user->is_suspended) {
            return response()->json([
                'message' => $user->suspension_reason
                    ? "This account has been suspended: {$user->suspension_reason}"
                    : 'This account has been suspended.',
            ], 403);
        }

        $token = $user->createToken($data['device_name'] ?? 'mobile')->plainTextToken;

        return (new UserResource($user))->asSelf()
            ->additional(['token' => $token, 'token_type' => 'Bearer'])
            ->response();
    }

    /**
     * The currently authenticated user — used by the mobile app to restore a session
     * (validate a stored token and refresh profile data) without a full re-login, and
     * to detect a suspension applied after the token was issued.
     */
    public function me(Request $request): UserResource
    {
        $user = $request->user()->loadCount([
            'posts',
            'listings as active_listings_count' => fn ($query) => $query->where('status', 'active'),
        ]);

        return (new UserResource($user))->asSelf();
    }

    /**
     * Update the caller's own profile — name, handle, bio, contact/location labels,
     * growing interests, the handover-radius visibility setting, and avatar/cover
     * photo. Every field is `sometimes`, so a client can send just the one field
     * it's changing.
     */
    public function updateProfile(UpdateProfileRequest $request, ImageService $imageService): UserResource
    {
        $user = $request->user();
        $data = $request->validated();

        $user->fill(array_intersect_key($data, array_flip([
            'name', 'username', 'bio', 'phone', 'location_label',
            'growing_interests', 'show_handover_radius',
            'experience_level', 'growing_setup',
        ])));

        if ($request->hasFile('avatar')) {
            $user->avatar_path = $imageService->store($request->file('avatar'), 'avatars');
        }

        if ($request->hasFile('cover_photo')) {
            $user->cover_photo_path = $imageService->store($request->file('cover_photo'), 'covers');
        }

        $user->save();

        $user->loadCount([
            'posts',
            'listings as active_listings_count' => fn ($query) => $query->where('status', 'active'),
        ]);

        return (new UserResource($user))->asSelf();
    }

    /**
     * Revoke the token used to make this request (i.e. sign out this device only).
     */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out.']);
    }
}
