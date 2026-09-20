<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\AppNotificationResource;
use App\Models\AppNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class NotificationController extends Controller
{
    private const PER_PAGE = 20;

    public function index(Request $request): AnonymousResourceCollection
    {
        $notifications = $request->user()->appNotifications()
            ->with('actor')
            ->latest()
            ->paginate(self::PER_PAGE)
            ->withQueryString();

        return AppNotificationResource::collection($notifications);
    }

    public function unreadCount(Request $request): JsonResponse
    {
        $count = $request->user()->appNotifications()->whereNull('read_at')->count();

        return response()->json(['unread_count' => $count]);
    }

    public function markRead(Request $request, AppNotification $notification): AppNotificationResource
    {
        $this->authorize('update', $notification);

        $notification->read_at ??= now();
        $notification->save();

        return new AppNotificationResource($notification);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        $request->user()->appNotifications()->whereNull('read_at')->update(['read_at' => now()]);

        return response()->json(['message' => 'All notifications marked as read.']);
    }
}
