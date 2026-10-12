<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Models\GroupRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class GroupRequestController extends Controller
{
    /**
     * "Want to make a new group? Request a group" — queued for admins on the
     * admin panel's Group Requests page.
     */
    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'description' => ['nullable', 'string', 'max:2000'],
        ]);

        $groupRequest = new GroupRequest($data);
        $groupRequest->user_id = $request->user()->id;
        $groupRequest->status = GroupRequest::STATUS_PENDING;
        $groupRequest->save();

        return response()->json([
            'message' => 'Thanks — our team will review your group request.',
            'data' => [
                'id' => $groupRequest->id,
                'name' => $groupRequest->name,
                'description' => $groupRequest->description,
                'status' => $groupRequest->status,
            ],
        ], 201);
    }
}
