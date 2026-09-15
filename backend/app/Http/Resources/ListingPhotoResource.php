<?php

namespace App\Http\Resources;

use App\Models\ListingPhoto;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ListingPhoto
 */
class ListingPhotoResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'url' => $this->resource->url(),
            'sort_order' => $this->sort_order,
        ];
    }
}
