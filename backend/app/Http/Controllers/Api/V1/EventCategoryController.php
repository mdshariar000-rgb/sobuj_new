<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\EventCategoryResource;
use App\Models\EventCategory;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class EventCategoryController extends Controller
{
    /**
     * The full admin-managed category list, for the Events tab's filter
     * chips and the "create an event" form — not paginated, since this is
     * always a short reference list an admin curates, not user-generated
     * content.
     */
    public function index(): AnonymousResourceCollection
    {
        return EventCategoryResource::collection(
            EventCategory::query()->orderBy('name')->get(),
        );
    }
}
