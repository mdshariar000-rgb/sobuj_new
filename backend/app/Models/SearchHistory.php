<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * A term a user searched for from Home. One row per user and term —
 * searching it again just bumps updated_at.
 */
class SearchHistory extends Model
{
    protected $fillable = ['term'];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
