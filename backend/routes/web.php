<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// This app is API-only outside the Filament admin panel (which has its own,
// panel-scoped auth flow). Laravel's default auth middleware falls back to
// route('login') for any unauthenticated request that doesn't explicitly send
// `Accept: application/json` — without this route, that lookup throws
// RouteNotFoundException instead of cleanly returning 401.
Route::get('/login', function () {
    abort(401, 'Unauthenticated.');
})->name('login');
