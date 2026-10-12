<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Illuminate\Http\JsonResponse;

/**
 * Features that were removed — the Agri-AI assistant and its Premium
 * subscription, and the personal Home timeline (general posts, post
 * categories, sharing to the timeline). Older app builds still call these
 * endpoints, so they answer 410 Gone with a message the app shows as-is,
 * instead of a bare 404. Safe to delete once no one runs those builds.
 */
class RetiredFeatureController extends Controller
{
    public const MESSAGE = 'This feature is no longer available. Please update the app.';

    public function __invoke(): JsonResponse
    {
        return response()->json(['message' => self::MESSAGE], 410);
    }
}
