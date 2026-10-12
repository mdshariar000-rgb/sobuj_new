<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'token' => env('POSTMARK_TOKEN'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'resend' => [
        'key' => env('RESEND_KEY'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    // UK address suggestions (see AddressLookupService). Free public server
    // by default; set to a self-hosted Photon to move off it.
    'photon' => [
        'url' => env('PHOTON_URL', 'https://photon.komoot.io'),
    ],

    // "Sign in with Google / Apple" (see SocialTokenVerifier): the OAuth
    // client ids an ID token may be issued for — iOS, Android and web, comma
    // separated. The admin Settings page can set these too, and wins.
    'google' => [
        'client_ids' => env('GOOGLE_CLIENT_IDS', ''),
    ],
    'apple' => [
        // Native iOS sign-in: tokens are issued for the app's bundle id.
        'client_id' => env('APPLE_CLIENT_ID', 'com.greenshelter.shobuj'),
    ],

    // Postcode → every address there (see PostcodeAddressService). The key
    // is normally saved on the admin Settings page, which beats this.
    'ideal_postcodes' => [
        'url' => env('IDEAL_POSTCODES_URL', 'https://api.ideal-postcodes.co.uk'),
        'key' => env('IDEAL_POSTCODES_KEY'),
    ],

];
