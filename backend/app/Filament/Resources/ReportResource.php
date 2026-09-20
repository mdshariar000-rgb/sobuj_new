<?php

namespace App\Filament\Resources;

use App\Enums\ReportReason;
use App\Enums\ReportStatus;
use App\Enums\ReportTargetType;
use App\Filament\Resources\ReportResource\Pages;
use App\Models\Report;
use Filament\Resources\Resource;
use Filament\Tables\Actions\Action;
use Filament\Tables\Actions\ActionGroup;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Support\Facades\Auth;

/**
 * The queue of user-filed reports (posts, comments, listings, events, groups, chat
 * messages, and users), filed from the mobile app. Read-only apart from the review
 * actions below — reports are created only by users, never by staff. The actual
 * takedown (ban a post, suspend a user, ...) happens on the reported item's own
 * resource via "Review content", which keeps a single moderation workflow per type;
 * types with no admin page of their own (comments, chat messages, events) can be
 * deleted straight from here.
 */
class ReportResource extends Resource
{
    protected static ?string $model = Report::class;

    protected static ?string $navigationIcon = 'heroicon-o-flag';

    protected static ?string $navigationLabel = 'Reports';

    protected static ?string $navigationGroup = 'Moderation';

    protected static ?int $navigationSort = 1;

    public static function getNavigationBadge(): ?string
    {
        $pending = Report::query()->where('status', ReportStatus::Pending)->count();

        return $pending > 0 ? (string) $pending : null;
    }

    public static function getNavigationBadgeColor(): ?string
    {
        return 'danger';
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canEdit($record): bool
    {
        return false;
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn ($query) => $query->with('reporter'))
            ->columns([
                TextColumn::make('created_at')
                    ->label('Reported')
                    ->since()
                    ->sortable(),

                TextColumn::make('target_type')
                    ->label('Type')
                    ->badge()
                    ->formatStateUsing(fn (ReportTargetType $state) => $state->label()),

                TextColumn::make('target_summary')
                    ->label('Reported item')
                    ->getStateUsing(fn (Report $record) => $record->targetSummary())
                    ->wrap()
                    ->limit(90),

                TextColumn::make('reason')
                    ->badge()
                    ->color('warning')
                    ->formatStateUsing(fn (ReportReason $state) => $state->label()),

                TextColumn::make('details')
                    ->limit(60)
                    ->placeholder('—')
                    ->tooltip(fn (Report $record) => $record->details),

                TextColumn::make('reporter.name')
                    ->label('Reported by')
                    ->searchable(),

                TextColumn::make('status')
                    ->badge()
                    ->color(fn (ReportStatus $state) => match ($state) {
                        ReportStatus::Pending => 'danger',
                        ReportStatus::Actioned => 'success',
                        ReportStatus::Dismissed => 'gray',
                    })
                    ->formatStateUsing(fn (ReportStatus $state) => $state->label()),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->options(collect(ReportStatus::cases())->mapWithKeys(fn ($case) => [$case->value => $case->label()])->all())
                    ->default(ReportStatus::Pending->value),

                SelectFilter::make('target_type')
                    ->label('Type')
                    ->options(collect(ReportTargetType::cases())->mapWithKeys(fn ($case) => [$case->value => $case->label()])->all()),

                SelectFilter::make('reason')
                    ->options(collect(ReportReason::cases())->mapWithKeys(fn ($case) => [$case->value => $case->label()])->all()),
            ])
            ->actions([
                Action::make('review')
                    ->label('Review content')
                    ->icon('heroicon-o-arrow-top-right-on-square')
                    ->url(fn (Report $record) => self::targetUrl($record), shouldOpenInNewTab: true)
                    ->visible(fn (Report $record) => self::targetUrl($record) !== null),

                ActionGroup::make([
                    Action::make('delete_content')
                        ->label('Delete reported content')
                        ->icon('heroicon-o-trash')
                        ->color('danger')
                        ->visible(fn (Report $record) => self::canDeleteDirectly($record))
                        ->requiresConfirmation()
                        ->modalDescription('Permanently deletes the reported item and marks every report against it as action taken.')
                        ->action(function (Report $record) {
                            $record->resolveTarget()?->delete();
                            self::resolveAllForTarget($record, ReportStatus::Actioned);
                        }),

                    Action::make('actioned')
                        ->label('Mark: action taken')
                        ->icon('heroicon-o-check-circle')
                        ->color('success')
                        ->visible(fn (Report $record) => $record->status === ReportStatus::Pending)
                        ->requiresConfirmation()
                        ->modalDescription('Marks this and every other pending report against the same item as handled.')
                        ->action(fn (Report $record) => self::resolveAllForTarget($record, ReportStatus::Actioned)),

                    Action::make('dismiss')
                        ->label('Dismiss report')
                        ->icon('heroicon-o-x-circle')
                        ->color('gray')
                        ->visible(fn (Report $record) => $record->status === ReportStatus::Pending)
                        ->requiresConfirmation()
                        ->modalDescription('No violation found. Dismisses this and every other pending report against the same item.')
                        ->action(fn (Report $record) => self::resolveAllForTarget($record, ReportStatus::Dismissed)),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    /**
     * Marks every still-pending report against the same item as resolved in one go —
     * three people reporting the same post shouldn't mean three separate reviews.
     */
    private static function resolveAllForTarget(Report $record, ReportStatus $status): void
    {
        Report::query()
            ->where('target_type', $record->target_type)
            ->where('target_id', $record->target_id)
            ->where('status', ReportStatus::Pending)
            ->get()
            ->each(function (Report $report) use ($status) {
                $report->status = $status;
                $report->reviewed_by = Auth::id();
                $report->reviewed_at = now();
                $report->save();
            });
    }

    private static function targetUrl(Report $record): ?string
    {
        $id = $record->target_id;

        if ($record->resolveTarget() === null) {
            return null;
        }

        return match ($record->target_type) {
            ReportTargetType::Post => PostResource::getUrl('edit', ['record' => $id]),
            ReportTargetType::Listing => ListingResource::getUrl('edit', ['record' => $id]),
            ReportTargetType::Group => GroupResource::getUrl('edit', ['record' => $id]),
            ReportTargetType::User => UserResource::getUrl('edit', ['record' => $id]),
            default => null,
        };
    }

    private static function canDeleteDirectly(Report $record): bool
    {
        return in_array($record->target_type, [
            ReportTargetType::Comment,
            ReportTargetType::GroupMessage,
            ReportTargetType::Message,
            ReportTargetType::Event,
        ], true) && $record->resolveTarget() !== null;
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListReports::route('/'),
        ];
    }
}
