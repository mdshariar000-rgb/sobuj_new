<?php

namespace App\Http\Resources;

use App\Models\SowingGuideMonth;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin SowingGuideMonth
 */
class SowingGuideMonthResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'month' => $this->month,
            'outdoors' => array_values($this->outdoors ?? []),
            'under_cover' => array_values($this->under_cover ?? []),
        ];
    }
}
