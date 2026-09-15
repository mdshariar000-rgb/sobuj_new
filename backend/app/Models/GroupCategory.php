<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * An admin-managed group category — the mobile app's "create a group" form
 * picks from this list rather than typing free text, and
 * StoreGroupRequest/UpdateGroupRequest validate against it by name (not a
 * foreign key on groups.category, so existing groups keep whatever category
 * they already had even if it's later removed from this list).
 */
class GroupCategory extends Model
{
    /**
     * @var list<string>
     */
    protected $fillable = [
        'name',
    ];
}
