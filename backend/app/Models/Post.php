<?php

namespace App\Models;

use App\Enums\PostApprovalStatus;
use App\Enums\PostModerationStatus;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * Serves both the general Home Feed (group_id null) and a group's discussion
 * thread (group_id set) — same shape either way: author, body, optional
 * image, comments.
 */
class Post extends Model
{
    use HasFactory;

    /**
     * What PostResource needs loaded to render a post in full.
     */
    public const RESOURCE_RELATIONS = ['author', 'group'];

    public const RESOURCE_COUNTS = ['comments', 'likedBy as likes_count'];

    /**
     * @var list<string>
     */
    protected $fillable = [
        'group_id',
        'body',
        'image_path',
    ];

    /**
     * approval_status/moderation_status are not added to $fillable — only
     * ever set by controller/Filament action logic, never mass-assigned
     * from request input, same pattern as Group's pinned_message/pinned_by.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'approval_status' => PostApprovalStatus::class,
            'moderation_status' => PostModerationStatus::class,
            'moderated_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<User, Post>
     */
    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Every post belongs to a group — there's no personal timeline.
     *
     * @return BelongsTo<Group, Post>
     */
    public function group(): BelongsTo
    {
        return $this->belongsTo(Group::class);
    }

    /**
     * @return HasMany<Comment>
     */
    public function comments(): HasMany
    {
        return $this->hasMany(Comment::class);
    }

    /**
     * @return BelongsToMany<User, Post>
     */
    public function likedBy(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'post_likes')->withPivot('created_at');
    }
}
