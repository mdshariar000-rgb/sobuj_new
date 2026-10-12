<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Mail\PasswordResetCode;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

/**
 * "Forgot password" for the app: email a 6-digit code, then reset with it.
 * Codes live (hashed) in Laravel's password_reset_tokens table.
 */
class PasswordResetController extends Controller
{
    private const CODE_TTL_MINUTES = 30;

    /** Wrong guesses allowed before the code stops working. */
    private const MAX_ATTEMPTS = 5;

    /**
     * Always answers the same way, so it can't be used to find out which
     * emails have accounts.
     */
    public function sendCode(Request $request): JsonResponse
    {
        $data = $request->validate(['email' => ['required', 'string', 'email', 'max:255']]);
        $email = strtolower($data['email']);

        $user = User::whereRaw('LOWER(email) = ?', [$email])->first();

        if ($user !== null) {
            $code = (string) random_int(100000, 999999);

            DB::table('password_reset_tokens')->updateOrInsert(
                ['email' => $email],
                ['token' => Hash::make($code), 'created_at' => now()],
            );
            Cache::forget($this->attemptsKey($email));

            Mail::to($user->email)->send(new PasswordResetCode($code));
        }

        return response()->json([
            'message' => 'If an account exists for that email, we have sent it a reset code.',
        ]);
    }

    public function reset(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'string', 'email', 'max:255'],
            'code' => ['required', 'string', 'size:6'],
            'password' => ['required', 'confirmed', Password::defaults()],
        ]);
        $email = strtolower($data['email']);

        $row = DB::table('password_reset_tokens')->where('email', $email)->first();
        $attemptsKey = $this->attemptsKey($email);

        $valid = $row !== null
            && now()->subMinutes(self::CODE_TTL_MINUTES)->lte($row->created_at)
            && Cache::get($attemptsKey, 0) < self::MAX_ATTEMPTS
            && Hash::check($data['code'], $row->token);

        if (! $valid) {
            Cache::put($attemptsKey, Cache::get($attemptsKey, 0) + 1, now()->addMinutes(self::CODE_TTL_MINUTES));

            throw ValidationException::withMessages([
                'code' => ['That code is wrong or has expired. Ask for a new one.'],
            ]);
        }

        $user = User::whereRaw('LOWER(email) = ?', [$email])->firstOrFail();
        $user->password = $data['password'];
        $user->forceFill(['has_password' => true])->save();

        // Signed out everywhere: whoever knew the old password loses access.
        $user->tokens()->delete();
        DB::table('password_reset_tokens')->where('email', $email)->delete();
        Cache::forget($attemptsKey);

        return response()->json(['message' => 'Your password has been reset. You can now log in.']);
    }

    private function attemptsKey(string $email): string
    {
        return 'password-reset-attempts:'.sha1($email);
    }
}
