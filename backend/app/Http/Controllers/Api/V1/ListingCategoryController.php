<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ListingCategoryResource;
use App\Models\ListingCategory;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class ListingCategoryController extends Controller
{
    /**
     * The full admin-managed category list, for the mobile app's "create a
     * listing" picker — not paginated, since this is always a short reference
     * list an admin curates, not user-generated content.
     */
    public function index(): AnonymousResourceCollection
    {
        return ListingCategoryResource::collection(
            ListingCategory::query()->orderBy('name')->get(),
        );
    }
}
