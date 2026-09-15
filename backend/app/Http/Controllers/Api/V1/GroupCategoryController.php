<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\GroupCategoryResource;
use App\Models\GroupCategory;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class GroupCategoryController extends Controller
{
    /**
     * The full admin-managed category list, for the mobile app's "create a
     * group" picker — not paginated, since this is always a short reference
     * list an admin curates, not user-generated content.
     */
    public function index(): AnonymousResourceCollection
    {
        return GroupCategoryResource::collection(
            GroupCategory::query()->orderBy('name')->get(),
        );
    }
}
