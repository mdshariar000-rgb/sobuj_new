<?php

use App\Models\Setting;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// Public legal pages — App Store Connect requires a real, publicly reachable
// privacy-policy URL (and a support contact) that doesn't need the app installed.
// The contact address is set from the admin panel's Settings page.
Route::get('/privacy', fn () => view('legal.privacy', [
    'updated' => 'September 20, 2026',
    'supportEmail' => Setting::get('support_email'),
]));

Route::get('/terms', fn () => view('legal.terms', [
    'updated' => 'September 20, 2026',
    'supportEmail' => Setting::get('support_email'),
]));

// This app is API-only outside the Filament admin panel (which has its own,
// panel-scoped auth flow). Laravel's default auth middleware falls back to
// route('login') for any unauthenticated request that doesn't explicitly send
// `Accept: application/json` — without this route, that lookup throws
// RouteNotFoundException instead of cleanly returning 401.
Route::get('/login', function () {
    abort(401, 'Unauthenticated.');
})->name('login');
