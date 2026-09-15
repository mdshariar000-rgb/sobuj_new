<?php

use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    // Registered explicitly (rather than via withRouting's `channels:` shorthand,
    // which defaults /broadcasting/auth to the `web` session-cookie guard) because
    // this is a Bearer-token mobile API: channel authorization must run through
    // Sanctum, or the Flutter client could never subscribe to a private channel.
    ->withBroadcasting(
        __DIR__.'/../routes/channels.php',
        ['middleware' => ['auth:sanctum']],
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->alias([
            'not_suspended' => \App\Http\Middleware\EnsureUserIsNotSuspended::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        // Every /api/* consumer is a JSON client (the Flutter app) — never redirect
        // to an HTML login page there, regardless of the request's Accept header.
        // Without this, an unauthenticated request lacking `Accept: application/json`
        // falls back to Laravel's default guest-redirect behavior instead of a clean
        // 401.
        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(['message' => $e->getMessage()], 401);
            }
        });
    })->create();
