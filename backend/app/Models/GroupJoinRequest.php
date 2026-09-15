<?php

namespace App\Models;

use App\Enums\GroupJoinRequestStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class GroupJoinRequest extends Model
{
    use HasFactory;

    /**
     * No created_at/updated_at columns — requested_at/decided_at already
     * cover "when was this filed" and "when was this decided", a redundant
     * pair of Eloquent's own timestamps would just duplicate that.
     */
    public $timestamps = false;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'group_id',
        'user_id',
        'status',
        'requested_at',
        'decided_at',
        'decided_by',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'status' => GroupJoinRequestStatus::class,
            'requested_at' => 'datetime',
            'decided_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<Group, GroupJoinRequest>
     */
    public function group(): BelongsTo
    {
        return $this->belongsTo(Group::class);
    }

    /**
     * @return BelongsTo<User, GroupJoinRequest>
     */
    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * @return BelongsTo<User, GroupJoinRequest>
     */
    public function decidedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'decided_by');
    }
}
