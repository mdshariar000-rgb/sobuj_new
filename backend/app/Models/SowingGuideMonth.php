<?php

namespace App\Models;

use Carbon\Carbon;
use Illuminate\Database\Eloquent\Model;

/**
 * One month of the admin-managed UK sowing guide behind the mobile app's
 * "What can you grow now?" screen — exactly 12 rows (seeded by the
 * migration), edited in the admin panel, never created or deleted.
 */
class SowingGuideMonth extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'outdoors',
        'under_cover',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'month' => 'integer',
            'outdoors' => 'array',
            'under_cover' => 'array',
        ];
    }

    public function monthName(): string
    {
        return Carbon::create(null, $this->month, 1)->format('F');
    }
}
