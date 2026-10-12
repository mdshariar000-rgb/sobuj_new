<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\SowingGuideMonthResource;
use App\Models\SowingGuideMonth;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class SowingGuideController extends Controller
{
    /**
     * All 12 months of the admin-managed sowing guide for the mobile app's
     * "What can you grow now?" screen — the app picks the current month on
     * the phone, so a guide fetched in late January is still right in February.
     */
    public function index(): AnonymousResourceCollection
    {
        return SowingGuideMonthResource::collection(
            SowingGuideMonth::query()->orderBy('month')->get(),
        );
    }
}
