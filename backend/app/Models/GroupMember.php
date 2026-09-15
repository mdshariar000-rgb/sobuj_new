<?php

namespace App\Models;

use App\Enums\GroupMemberRole;
use Illuminate\Database\Eloquent\Relations\Pivot;

/**
 * Pivot model for the groups <-> users belongsToMany (see Group::members()),
 * used via ->using() rather than the plain default pivot so role-checking
 * logic has a proper home and the enum cast applies.
 */
class GroupMember extends Pivot
{
    /**
     * The group_members table has its own auto-incrementing id (not a
     * composite-key-only pivot), unlike Pivot's default assumption.
     *
     * @var bool
     */
    public $incrementing = true;

    /**
     * @var string
     */
    protected $table = 'group_members';

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'role' => GroupMemberRole::class,
            'joined_at' => 'datetime',
        ];
    }

    public function isAdmin(): bool
    {
        return $this->role === GroupMemberRole::Admin;
    }
}
