<?php

namespace App\Models;

use App\Enums\GroupStatus;
use App\Enums\GroupVisibility;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Group extends Model
{
    use HasFactory;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'slug',
        'description',
        'category',
        'visibility',
        'cover_image_path',
        'avatar_path',
    ];

    /**
     * status/verified_at are not in $fillable — site-wide admin moderation,
     * only ever set via Filament\Resources\GroupResource actions, never
     * mass-assigned from request input. Mirrors Post's approval/moderation
     * fields and User's verified_at.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'visibility' => GroupVisibility::class,
            'status' => GroupStatus::class,
            'verified_at' => 'datetime',
            'pinned_at' => 'datetime',
        ];
    }

    public function isPrivate(): bool
    {
        return $this->visibility === GroupVisibility::Private;
    }

    public function isActive(): bool
    {
        return $this->status === GroupStatus::Active;
    }

    /**
     * @return BelongsTo<User, Group>
     */
    public function creator(): BelongsTo
    {
        return $this->belongsTo(User::class, 'created_by');
    }

    /**
     * @return BelongsToMany<User, Group>
     */
    public function members(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'group_members')
            ->using(GroupMember::class)
            ->withPivot(['role', 'joined_at']);
    }

    /**
     * This group's discussion-thread posts (as opposed to general Home Feed
     * posts, which have a null group_id — see Post::scopeGeneralFeed()).
     *
     * @return HasMany<Post>
     */
    public function posts(): HasMany
    {
        return $this->hasMany(Post::class);
    }

    /**
     * @return HasMany<Event>
     */
    public function events(): HasMany
    {
        return $this->hasMany(Event::class);
    }

    /**
     * This group's real-time chat thread — distinct from posts(), which is
     * the async discussion feed.
     *
     * @return HasMany<GroupMessage>
     */
    public function messages(): HasMany
    {
        return $this->hasMany(GroupMessage::class);
    }

    /**
     * The most recent chat message in this group — used for the Groups
     * list's conversation-preview, the same role SwapOffer::latestMessage()
     * plays for the marketplace inbox.
     *
     * @return HasOne<GroupMessage>
     */
    public function latestMessage(): HasOne
    {
        return $this->hasOne(GroupMessage::class)->latestOfMany();
    }

    /**
     * @return BelongsTo<User, Group>
     */
    public function pinnedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'pinned_by');
    }

    /**
     * Pending/rejected requests to join this group — only relevant while
     * private (see GroupController::join()); a request is deleted (not
     * marked "approved") once accepted, replaced by a real members() row.
     *
     * @return HasMany<GroupJoinRequest>
     */
    public function joinRequests(): HasMany
    {
        return $this->hasMany(GroupJoinRequest::class);
    }
}
