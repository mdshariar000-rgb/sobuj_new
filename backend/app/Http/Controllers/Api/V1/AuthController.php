<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Requests\Auth\RegisterRequest;
use App\Http\Requests\Auth\SocialLoginRequest;
use App\Http\Requests\Auth\UpdateProfileRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use App\Services\AccountDeletionService;
use App\Services\AppleTokenRevoker;
use App\Services\ImageService;
use App\Services\InvalidSocialToken;
use App\Services\SocialTokenVerifier;
use App\Support\UkAddress;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use RuntimeException;

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
                'location_label' => $data['location_label'] ?? null,
                'growing_interests' => $data['growing_interests'] ?? null,
                ...array_intersect_key($data, array_flip(UkAddress::FIELDS)),
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
     * "Sign in with Google / Apple". Finds the account by the provider's id,
     * then by a verified email (linking it). A new person gets
     * `needs_signup` back with what the provider told us, and the app calls
     * again with the address sign-up always asks for to create the account.
     */
    public function social(SocialLoginRequest $request, SocialTokenVerifier $verifier): JsonResponse
    {
        $data = $request->validated();
        $provider = $data['provider'];
        $column = $provider.'_id';

        try {
            $identity = $verifier->verify($provider, $data['id_token'], $data['nonce'] ?? null);
        } catch (InvalidSocialToken $e) {
            return response()->json(['message' => $e->getMessage()], 401);
        } catch (RuntimeException $e) {
            report($e);

            return response()->json(['message' => 'Sign-in is unavailable right now. Please try again.'], 503);
        }

        $user = User::where($column, $identity['id'])->first();

        if (! $user && $identity['email'] && $identity['email_verified']) {
            $user = User::where('email', $identity['email'])->first();
            if ($user && $user->{$column} === null) {
                $user->forceFill([$column => $identity['id']])->save();
            }
        }

        if (! $user) {
            if (! $identity['email']) {
                return response()->json([
                    'message' => 'We need your email address to create an account. Please share it, or sign up with email.',
                ], 422);
            }

            if (! $request->filled('address_postcode')) {
                return response()->json([
                    'needs_signup' => true,
                    'email' => $identity['email'],
                    'name' => $data['name'] ?? $identity['name'],
                ]);
            }

            $user = DB::transaction(function () use ($data, $identity, $column): User {
                $user = new User([
                    'name' => $data['name'],
                    'email' => $identity['email'],
                    // Never typed; "Forgot password?" sets a real one if wanted.
                    'password' => Str::password(40),
                    'experience_level' => $data['experience_level'] ?? null,
                    'growing_setup' => $data['growing_setup'] ?? null,
                    'location_label' => $data['location_label'] ?? null,
                    'growing_interests' => $data['growing_interests'] ?? null,
                    ...array_intersect_key($data, array_flip(UkAddress::FIELDS)),
                ]);
                $user->forceFill([
                    $column => $identity['id'],
                    'has_password' => false,
                    'email_verified_at' => $identity['email_verified'] ? now() : null,
                ]);
                $user->setLocation((float) $data['latitude'], (float) $data['longitude']);
                $user->save();

                return $user;
            });

            $created = true;
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
            ->additional(['token' => $token, 'token_type' => 'Bearer', 'is_new_user' => $created ?? false])
            ->response()
            ->setStatusCode(isset($created) ? 201 : 200);
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
            'followers',
            'following',
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
            ...UkAddress::FIELDS,
        ])));

        if (isset($data['latitude'], $data['longitude'])) {
            $user->setLocation((float) $data['latitude'], (float) $data['longitude']);
        }

        if ($request->hasFile('avatar')) {
            $user->avatar_path = $imageService->store($request->file('avatar'), 'avatars');
        }

        if ($request->hasFile('cover_photo')) {
            $user->cover_photo_path = $imageService->store($request->file('cover_photo'), 'covers');
        }

        $user->save();

        $user->loadCount([
            'posts',
            'followers',
            'following',
            'listings as active_listings_count' => fn ($query) => $query->where('status', 'active'),
        ]);

        return (new UserResource($user))->asSelf();
    }

    /**
     * Permanently delete the caller's own account and personal data (App Store
     * Guideline 5.1.1(v)). Requires the current password so a stolen session token
     * alone can't wipe an account. Not behind `not_suspended` — a suspended user must
     * still be able to leave and have their data removed.
     */
    public function destroy(Request $request, AccountDeletionService $accountDeletion, SocialTokenVerifier $verifier, AppleTokenRevoker $appleRevoker): JsonResponse
    {
        // Confirmed with the password — or, for an account made with Google
        // or Apple that never had one, by signing in with that again.
        $request->validate([
            'password' => ['required_without:id_token', 'nullable', 'string'],
            'provider' => ['required_with:id_token', 'nullable', 'in:google,apple'],
            'id_token' => ['nullable', 'string', 'max:8000'],
            'nonce' => ['nullable', 'string', 'max:255'],
            // Apple: a fresh code from re-confirming, to revoke the link.
            'authorization_code' => ['nullable', 'string', 'max:2000'],
        ]);

        $user = $request->user();

        if ($request->filled('id_token')) {
            $provider = $request->input('provider');
            try {
                $identity = $verifier->verify($provider, $request->input('id_token'), $request->input('nonce'), evenIfSwitchedOff: true);
            } catch (InvalidSocialToken $e) {
                throw ValidationException::withMessages(['id_token' => [$e->getMessage()]]);
            } catch (RuntimeException $e) {
                report($e);

                return response()->json(['message' => 'Sign-in is unavailable right now. Please try again.'], 503);
            }

            if ($user->{$provider.'_id'} === null || ! hash_equals((string) $user->{$provider.'_id'}, $identity['id'])) {
                throw ValidationException::withMessages([
                    'id_token' => ['That '.ucfirst($provider).' account isn\'t the one linked to this account.'],
                ]);
            }
        } elseif (! Hash::check((string) $request->input('password'), $user->password)) {
            throw ValidationException::withMessages([
                'password' => ['The password is incorrect.'],
            ]);
        }

        // Apple asks apps to revoke "Sign in with Apple" on deletion. Never
        // blocks the deletion itself — a failure is only logged.
        if ($user->apple_id !== null && $request->filled('authorization_code') && $appleRevoker->isConfigured()) {
            try {
                $appleRevoker->revoke($request->input('authorization_code'));
            } catch (RuntimeException $e) {
                report($e);
            }
        }

        try {
            $accountDeletion->delete($user);
        } catch (\Throwable $e) {
            report($e);

            return response()->json([
                'message' => 'Your account could not be deleted right now. Please try again shortly.',
            ], 503);
        }

        return response()->json(['message' => 'Your account has been deleted.']);
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
