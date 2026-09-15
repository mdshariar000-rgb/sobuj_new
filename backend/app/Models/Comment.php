<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Comment extends Model
{
    use HasFactory;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'post_id',
        'parent_id',
        'body',
        'replying_to_user_id',
    ];

    /**
     * @return BelongsTo<Post, Comment>
     */
    public function post(): BelongsTo
    {
        return $this->belongsTo(Post::class);
    }

    /**
     * @return BelongsTo<User, Comment>
     */
    public function author(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Null for a top-level comment — see the parent_id column comment on the
     * comments table migration for why this never points at another reply.
     *
     * @return BelongsTo<Comment, Comment>
     */
    public function parent(): BelongsTo
    {
        return $this->belongsTo(Comment::class, 'parent_id');
    }

    /**
     * @return HasMany<Comment>
     */
    public function replies(): HasMany
    {
        return $this->hasMany(Comment::class, 'parent_id');
    }

    /**
     * The specific person this reply is addressing (for the bold name
     * prefix) — may differ from parent()->author when replying to a reply.
     *
     * @return BelongsTo<User, Comment>
     */
    public function replyingToUser(): BelongsTo
    {
        return $this->belongsTo(User::class, 'replying_to_user_id');
    }
}
