<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\PostCategoryResource;
use App\Models\PostCategory;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class PostCategoryController extends Controller
{
    /**
     * The full admin-managed category list, for the Home tab's Recent/
     * Disease Alerts/Harvests chips and the "new post" composer — not
     * paginated, since this is always a short reference list an admin
     * curates, not user-generated content.
     */
    public function index(): AnonymousResourceCollection
    {
        return PostCategoryResource::collection(
            PostCategory::query()->orderBy('name')->get(),
        );
    }
}
