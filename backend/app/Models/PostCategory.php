<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * An admin-managed post category — backs the Home tab's Recent/Disease
 * Alerts/Harvests chips and the "new post" composer's category picker.
 * StorePostRequest/HomeFeedController validate against this list by name
 * (not a foreign key on posts.category), so existing posts keep whatever
 * category they already had even if it's later removed from this list.
 */
class PostCategory extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'name',
    ];
}
