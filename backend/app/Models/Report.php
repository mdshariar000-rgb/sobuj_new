<?php

namespace App\Models;

use App\Enums\ReportReason;
use App\Enums\ReportStatus;
use App\Enums\ReportTargetType;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Str;

/**
 * A user-filed report against another user or a piece of content. Written only by
 * ReportController (direct attribute assignment, no $fillable) and reviewed by staff
 * in the Filament admin panel — the moderation trail App Store Guideline 1.2 asks for.
 */
class Report extends Model
{
    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'target_type' => ReportTargetType::class,
            'reason' => ReportReason::class,
            'status' => ReportStatus::class,
            'reviewed_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<User, Report>
     */
    public function reporter(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reporter_id');
    }

    /**
     * @return BelongsTo<User, Report>
     */
    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    /**
     * The reported row, or null once it has since been deleted.
     */
    public function resolveTarget(): ?Model
    {
        return $this->target_type->modelClass()::query()->find($this->target_id);
    }

    /**
     * A short human-readable description of what was reported, for the admin table.
     */
    public function targetSummary(): string
    {
        $target = $this->resolveTarget();

        if ($target === null) {
            return '(deleted)';
        }

        return match ($this->target_type) {
            ReportTargetType::Post, ReportTargetType::Comment => Str::limit((string) $target->body, 80),
            ReportTargetType::Listing, ReportTargetType::Event => (string) $target->title,
            ReportTargetType::Group, ReportTargetType::User => (string) $target->name,
            ReportTargetType::GroupMessage, ReportTargetType::Message => $target->body !== null
                ? Str::limit((string) $target->body, 80)
                : '(photo)',
        };
    }

    /**
     * The user who wrote/owns the reported content, if it still exists.
     */
    public function targetOwner(): ?User
    {
        $target = $this->resolveTarget();
        $ownerId = $target?->getAttribute($this->target_type->ownerColumn());

        return $ownerId !== null ? User::query()->find($ownerId) : null;
    }
}
