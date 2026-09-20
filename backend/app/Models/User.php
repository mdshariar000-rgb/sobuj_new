<?php

namespace App\Models;

use App\Enums\ExperienceLevel;
use App\Enums\GrowingSetup;
use App\Enums\SwapOfferStatus;
use App\Models\Concerns\HasFuzzyLocation;
// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Filament\Models\Contracts\FilamentUser;
use Filament\Panel;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\BelongsToMany;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Laravel\Cashier\Billable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable implements FilamentUser
{
    /** @use HasFactory<UserFactory> */
    use Billable, HasApiTokens, HasFactory, HasFuzzyLocation, Notifiable;

    /**
     * The attributes that are mass assignable.
     *
     * is_admin/is_suspended/suspension_reason/verified_at are only ever written from
     * inside the Filament admin panel (see App\Filament\Resources\UserResource), never
     * from a public API request — those requests build explicit field allowlists via
     * FormRequest::validated() rather than forwarding raw input, so having these
     * fillable here doesn't reopen a mass-assignment hole.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'experience_level',
        'growing_setup',
        'is_admin',
        'is_suspended',
        'suspension_reason',
        'suspended_until',
        'verified_at',
        'avatar_path',
        'cover_photo_path',
        'username',
        'bio',
        'phone',
        'location_label',
        'growing_interests',
        'show_handover_radius',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * base_location/fuzzy_location are raw WKB binary and are never meaningful (or
     * safe, in base_location's case) to serialize directly — expose coordinates
     * explicitly via getFuzzyCoordinates()/scopeSelectFuzzyCoordinates() instead.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
        'base_location',
        'fuzzy_location',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'rating_avg' => 'decimal:2',
            'experience_level' => ExperienceLevel::class,
            'growing_setup' => GrowingSetup::class,
            'is_admin' => 'boolean',
            'is_suspended' => 'boolean',
            'suspended_until' => 'datetime',
            'verified_at' => 'datetime',
            'growing_interests' => 'array',
            'show_handover_radius' => 'boolean',
            'trial_ends_at' => 'datetime',
        ];
    }

    /**
     * Whether this user currently has paid (or trialing) access to the
     * Agri-AI Assistant — see AiConversationPolicy. Backed entirely by
     * Cashier's own `subscriptions` table (via the Billable trait above,
     * kept in sync by Stripe webhooks), not a separate status column, so
     * there's nothing here that can drift out of sync with Stripe itself.
     */
    public function hasAgriAiAccess(): bool
    {
        return $this->subscribed('default');
    }

    /**
     * True while a ban is actually in effect right now — a temporary ban
     * (suspended_until in the future) self-expires without any cron job or
     * manual "unsuspend" needed; a permanent ban (suspended_until null)
     * never does. See EnsureUserIsNotSuspended.
     */
    public function isCurrentlySuspended(): bool
    {
        return $this->is_suspended
            && ($this->suspended_until === null || $this->suspended_until->isFuture());
    }

    public function avatarUrl(): ?string
    {
        return $this->avatar_path !== null
            ? Storage::disk('public')->url($this->avatar_path)
            : null;
    }

    public function coverPhotoUrl(): ?string
    {
        return $this->cover_photo_path !== null
            ? Storage::disk('public')->url($this->cover_photo_path)
            : null;
    }

    /**
     * Only staff accounts may authenticate into the Filament admin panel — every other
     * row in this table is a Shobuj end user, not an admin.
     */
    public function canAccessPanel(Panel $panel): bool
    {
        return $this->is_admin;
    }

    /**
     * Adds a `completed_swaps_count` column: the number of swap offers involving this
     * user (as either the requester or the owner of the listing) that reached
     * `completed`. A correlated subquery rather than two separate withCount() calls
     * summed in PHP, so it stays a single query and works with Filament's table sorting.
     */
    public function scopeWithCompletedSwapsCount(Builder $query): Builder
    {
        $completedSwapsCount = SwapOffer::query()
            ->join('listings', 'listings.id', '=', 'swap_offers.listing_id')
            ->where('swap_offers.status', SwapOfferStatus::Completed)
            ->where(function (Builder $q) {
                $q->whereColumn('swap_offers.requester_id', 'users.id')
                    ->orWhereColumn('listings.user_id', 'users.id');
            })
            ->selectRaw('count(*)');

        return $query->addSelect(['completed_swaps_count' => $completedSwapsCount]);
    }

    /**
     * Listings this user has posted.
     *
     * @return HasMany<Listing>
     */
    public function listings(): HasMany
    {
        return $this->hasMany(Listing::class);
    }

    /**
     * Listings this user has tapped the heart/save icon on — the "Favorites"
     * list. The pivot only carries `created_at` (when saved), not
     * `updated_at`, so timestamps aren't auto-managed here.
     *
     * @return BelongsToMany<Listing>
     */
    public function savedListings(): BelongsToMany
    {
        return $this->belongsToMany(Listing::class, 'saved_listings')
            ->withPivot('created_at');
    }

    /**
     * Events this user has tapped the bookmark/save icon on — the "Saved
     * Events" list. The pivot only carries `created_at` (when saved), not
     * `updated_at`, so timestamps aren't auto-managed here.
     *
     * @return BelongsToMany<Event>
     */
    public function savedEvents(): BelongsToMany
    {
        return $this->belongsToMany(Event::class, 'saved_events')
            ->withPivot('created_at');
    }

    /**
     * Swap offers this user has made on other users' listings.
     *
     * @return HasMany<SwapOffer>
     */
    public function swapOffers(): HasMany
    {
        return $this->hasMany(SwapOffer::class, 'requester_id');
    }

    /**
     * Messages this user has sent across any swap offer thread.
     *
     * @return HasMany<Message>
     */
    public function messages(): HasMany
    {
        return $this->hasMany(Message::class, 'sender_id');
    }

    /**
     * Groups this user is a member of (see Group::members() for the inverse).
     *
     * @return BelongsToMany<Group, User>
     */
    public function groups(): BelongsToMany
    {
        return $this->belongsToMany(Group::class, 'group_members')
            ->using(GroupMember::class)
            ->withPivot(['role', 'joined_at']);
    }

    /**
     * This user's posts, across both the general Home Feed and any groups.
     *
     * @return HasMany<Post>
     */
    public function posts(): HasMany
    {
        return $this->hasMany(Post::class, 'author_id');
    }

    /**
     * @return HasMany<Comment>
     */
    public function comments(): HasMany
    {
        return $this->hasMany(Comment::class, 'author_id');
    }

    /**
     * Events this user is hosting (as opposed to attending — see Event::attendees()
     * for the RSVP side).
     *
     * @return HasMany<Event>
     */
    public function hostedEvents(): HasMany
    {
        return $this->hasMany(Event::class, 'host_id');
    }

    /**
     * @return HasMany<AiConversation>
     */
    public function aiConversations(): HasMany
    {
        return $this->hasMany(AiConversation::class);
    }

    /**
     * This user's real in-app notification inbox — see AppNotification for
     * why it isn't named notifications()/backed by the dormant Notifiable
     * trait already `use`d above.
     *
     * @return HasMany<AppNotification>
     */
    public function appNotifications(): HasMany
    {
        return $this->hasMany(AppNotification::class, 'recipient_id');
    }

    /**
     * @return HasMany<DeviceToken>
     */
    public function deviceTokens(): HasMany
    {
        return $this->hasMany(DeviceToken::class);
    }

    /**
     * Users this account has blocked. The pivot only carries `created_at`, so
     * timestamps aren't auto-managed — pass it explicitly when attaching.
     *
     * @return BelongsToMany<User>
     */
    public function blockedUsers(): BelongsToMany
    {
        return $this->belongsToMany(User::class, 'user_blocks', 'blocker_id', 'blocked_id')
            ->withPivot('created_at');
    }

    /**
     * Every user id this account should neither see nor interact with: the users it
     * blocked plus the users who blocked it. Blocking is deliberately mutual in
     * effect — otherwise a blocked user could still watch the person who blocked them.
     * Memoized for the request (a User instance lives for one request).
     *
     * @return list<int>
     */
    public function hiddenUserIds(): array
    {
        if ($this->hiddenUserIdsCache === null) {
            $blocked = DB::table('user_blocks')->where('blocker_id', $this->id)->pluck('blocked_id');
            $blockedBy = DB::table('user_blocks')->where('blocked_id', $this->id)->pluck('blocker_id');

            $this->hiddenUserIdsCache = $blocked->merge($blockedBy)->map(fn ($id) => (int) $id)->unique()->values()->all();
        }

        return $this->hiddenUserIdsCache;
    }

    public function hasBlockRelationWith(User|int $other): bool
    {
        return in_array($other instanceof User ? $other->id : $other, $this->hiddenUserIds(), true);
    }

    /**
     * @var list<int>|null
     */
    private ?array $hiddenUserIdsCache = null;
}
