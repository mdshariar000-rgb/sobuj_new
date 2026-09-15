<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\Setting;
use Illuminate\Http\JsonResponse;

class ConfigController extends Controller
{
    /**
     * The current Stripe publishable key plus the real Agri-AI Premium
     * prices — public and unauthenticated (same class of route as
     * /auth/register), so the mobile app doesn't need any of this compiled
     * in at build time: an admin rotating the key or changing a price via
     * the Settings page takes effect immediately, no new APK required. The
     * mobile paywall reads monthly_price_usd/annual_price_usd from here
     * rather than hardcoding a figure that could silently drift from what
     * Stripe actually charges.
     */
    public function stripeKey(): JsonResponse
    {
        return response()->json([
            'publishable_key' => config('cashier.key'),
            'monthly_price_usd' => (float) Setting::get('stripe_monthly_price_usd', '9.99'),
            'annual_price_usd' => (float) Setting::get('stripe_annual_price_usd', '71.88'),
        ]);
    }
}
