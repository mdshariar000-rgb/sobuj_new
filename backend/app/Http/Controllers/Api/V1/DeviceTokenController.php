<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\DeviceToken\StoreDeviceTokenRequest;
use App\Models\DeviceToken;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceTokenController extends Controller
{
    /**
     * Registers (or re-registers) this device's FCM token against the
     * signed-in user. Upserts by token alone, not user_id+token — if the
     * same physical token was previously registered under a different
     * account (a shared device, or logging in as someone else on it), this
     * reassigns it so the old owner stops receiving that device's pushes.
     */
    public function store(StoreDeviceTokenRequest $request): JsonResponse
    {
        $data = $request->validated();

        DeviceToken::query()->updateOrCreate(
            ['token' => $data['token']],
            [
                'user_id' => $request->user()->id,
                'platform' => $data['platform'] ?? 'android',
                'device_id' => $data['device_id'] ?? null,
                'app_version' => $data['app_version'] ?? null,
                'last_used_at' => now(),
            ],
        );

        return response()->json(['message' => 'Device token registered.']);
    }

    /**
     * Scoped to the caller's own user_id — one account can't remove
     * another's token even if it somehow knew the value.
     */
    public function destroy(Request $request): JsonResponse
    {
        $request->validate(['token' => ['required', 'string']]);

        DeviceToken::query()
            ->where('token', $request->string('token'))
            ->where('user_id', $request->user()->id)
            ->delete();

        return response()->json(['message' => 'Device token removed.']);
    }
}
