<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Blocks every authenticated API request from a suspended account — not just
 * login. Without this, an admin suspending a user via Filament (UserResource)
 * would have no effect on a device that already holds a valid Sanctum token:
 * suspension would only ever stop *new* logins, not an existing session.
 */
class EnsureUserIsNotSuspended
{
    public function handle(Request $request, Closure $next): Response
    {
        if ($request->user()?->isCurrentlySuspended()) {
            return response()->json([
                'message' => 'This account has been suspended.',
            ], 403);
        }

        return $next($request);
    }
}
