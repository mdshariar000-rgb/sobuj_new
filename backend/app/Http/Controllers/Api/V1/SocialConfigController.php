<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Support\SocialSettings;
use Illuminate\Http\JsonResponse;

/**
 * What the app needs to show "Sign in with Google / Apple" — the public
 * client ids from the admin Settings page (never the Apple private key), so
 * they can change without a new app build. Public: it's read before sign-in.
 */
class SocialConfigController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $s = SocialSettings::all();
        $google = SocialSettings::googleEnabled($s);

        return response()->json(['data' => [
            'google' => [
                'enabled' => $google,
                'ios_client_id' => $google ? ($s[SocialSettings::GOOGLE_IOS_CLIENT_ID] ?: null) : null,
                'server_client_id' => $google ? ($s[SocialSettings::GOOGLE_SERVER_CLIENT_ID] ?: null) : null,
            ],
            'apple' => [
                'enabled' => SocialSettings::appleEnabled($s),
            ],
        ]]);
    }
}
