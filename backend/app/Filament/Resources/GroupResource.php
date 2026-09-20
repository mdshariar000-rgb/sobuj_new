<?php

namespace App\Filament\Resources;

use App\Enums\GroupStatus;
use App\Enums\GroupVisibility;
use App\Filament\Resources\GroupResource\Pages;
use App\Models\Group;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables\Actions\Action;
use Filament\Tables\Actions\ActionGroup;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

/**
 * Site-wide moderation over every group — groups are created by users
 * through the mobile app, not by admins.
 */
class GroupResource extends Resource
{
    protected static ?string $model = Group::class;

    protected static ?string $navigationIcon = 'heroicon-o-user-group';

    protected static ?string $navigationLabel = 'Groups';

    protected static ?string $navigationGroup = 'Moderation';

    protected static ?int $navigationSort = 3;

    public static function canCreate(): bool
    {
        return false;
    }

    public static function form(Form $form): Form
    {
        return $form->schema([
            TextInput::make('name')
                ->required()
                ->maxLength(255),

            TextInput::make('slug')
                ->required()
                ->maxLength(255)
                ->unique(ignoreRecord: true),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn (Builder $query) => $query->withCount('members'))
            ->columns([
                TextColumn::make('name')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('creator.name')
                    ->label('Creator')
                    ->searchable(),

                TextColumn::make('visibility')
                    ->badge()
                    ->color(fn (GroupVisibility $state) => $state === GroupVisibility::Private ? 'gray' : 'success')
                    ->formatStateUsing(fn (GroupVisibility $state) => $state->label()),

                TextColumn::make('members_count')
                    ->label('Members')
                    ->numeric()
                    ->sortable(),

                TextColumn::make('status')
                    ->badge()
                    ->color(fn (GroupStatus $state) => match ($state) {
                        GroupStatus::Active => 'success',
                        GroupStatus::Deactivated => 'warning',
                        GroupStatus::Banned => 'danger',
                    })
                    ->formatStateUsing(fn (GroupStatus $state) => $state->label()),

                IconColumn::make('verified_at')
                    ->label('Verified')
                    ->boolean()
                    ->getStateUsing(fn (Group $record) => $record->verified_at !== null)
                    ->sortable(),

                TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('status')
                    ->options(self::enumOptions(GroupStatus::cases())),

                SelectFilter::make('visibility')
                    ->options(self::enumOptions(GroupVisibility::cases())),
            ])
            ->actions([
                ActionGroup::make([
                    EditAction::make(),

                    Action::make('verify')
                        ->label('Verify')
                        ->icon('heroicon-o-check-badge')
                        ->color('success')
                        ->visible(fn (Group $record) => $record->verified_at === null)
                        ->requiresConfirmation()
                        ->action(fn (Group $record) => self::setVerified($record, true)),

                    Action::make('unverify')
                        ->label('Remove verification')
                        ->icon('heroicon-o-x-circle')
                        ->color('gray')
                        ->visible(fn (Group $record) => $record->verified_at !== null)
                        ->requiresConfirmation()
                        ->action(fn (Group $record) => self::setVerified($record, false)),

                    Action::make('deactivate')
                        ->label('Deactivate')
                        ->icon('heroicon-o-eye-slash')
                        ->color('warning')
                        ->visible(fn (Group $record) => $record->status === GroupStatus::Active)
                        ->requiresConfirmation()
                        ->modalDescription('Hides this group from the app for everyone. Reversible via Reactivate.')
                        ->form([
                            Textarea::make('reason')
                                ->label('Reason')
                                ->required()
                                ->maxLength(1000),
                        ])
                        ->action(fn (Group $record, array $data) => self::setStatus(
                            $record,
                            GroupStatus::Deactivated,
                            $data['reason'],
                        )),

                    Action::make('reactivate')
                        ->label('Reactivate')
                        ->icon('heroicon-o-eye')
                        ->color('success')
                        ->visible(fn (Group $record) => $record->status === GroupStatus::Deactivated)
                        ->requiresConfirmation()
                        ->action(fn (Group $record) => self::setStatus($record, GroupStatus::Active, null)),

                    Action::make('ban')
                        ->label('Ban permanently')
                        ->icon('heroicon-o-no-symbol')
                        ->color('danger')
                        ->visible(fn (Group $record) => $record->status !== GroupStatus::Banned)
                        ->requiresConfirmation()
                        ->form([
                            Textarea::make('reason')
                                ->label('Reason')
                                ->required()
                                ->maxLength(1000),
                        ])
                        ->action(fn (Group $record, array $data) => self::setStatus(
                            $record,
                            GroupStatus::Banned,
                            $data['reason'],
                        )),

                    Action::make('restore')
                        ->label('Restore')
                        ->icon('heroicon-o-arrow-uturn-left')
                        ->color('success')
                        ->visible(fn (Group $record) => $record->status === GroupStatus::Banned)
                        ->requiresConfirmation()
                        ->action(fn (Group $record) => self::setStatus($record, GroupStatus::Active, null)),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    /**
     * status/moderation_reason/verified_at aren't mass-assignable (see
     * Group::casts()'s docblock) — set directly rather than via update().
     */
    private static function setStatus(Group $record, GroupStatus $status, ?string $reason): void
    {
        $record->status = $status;
        $record->moderation_reason = $reason;
        $record->save();
    }

    private static function setVerified(Group $record, bool $verified): void
    {
        $record->verified_at = $verified ? now() : null;
        $record->save();
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListGroups::route('/'),
            'edit' => Pages\EditGroup::route('/{record}/edit'),
        ];
    }

    /**
     * @param  array<int, GroupStatus|GroupVisibility>  $cases
     * @return array<string, string>
     */
    private static function enumOptions(array $cases): array
    {
        return collect($cases)->mapWithKeys(fn ($case) => [$case->value => $case->label()])->all();
    }
}
