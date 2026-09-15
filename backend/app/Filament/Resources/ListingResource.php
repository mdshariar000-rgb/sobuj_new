<?php

namespace App\Filament\Resources;

use App\Enums\ListingStatus;
use App\Enums\ListingType;
use App\Enums\TransactionType;
use App\Filament\Resources\ListingResource\Pages;
use App\Models\Listing;
use Filament\Forms\Components\Select;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Forms\Form;
use Filament\Resources\Resource;
use Filament\Tables\Actions\Action;
use Filament\Tables\Actions\ActionGroup;
use Filament\Tables\Actions\EditAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

/**
 * Doubles as the moderation queue: defaults to showing flagged listings first (see the
 * `is_flagged` filter's default(true)), with Approve/Delete/Flag User actions to
 * resolve a report.
 */
class ListingResource extends Resource
{
    protected static ?string $model = Listing::class;

    protected static ?string $navigationIcon = 'heroicon-o-flag';

    protected static ?string $navigationLabel = 'Listing Moderation';

    protected static ?string $navigationGroup = 'Community';

    /**
     * Listings are created by users through the mobile app, not by admins — this
     * resource is for reviewing/moderating existing ones.
     */
    public static function canCreate(): bool
    {
        return false;
    }

    public static function form(Form $form): Form
    {
        return $form->schema([
            TextInput::make('title')
                ->required()
                ->maxLength(255),

            TextInput::make('variety')
                ->maxLength(255),

            Select::make('listing_type')
                ->options(self::enumOptions(ListingType::cases()))
                ->native(false)
                ->required(),

            Select::make('transaction_type')
                ->options(self::enumOptions(TransactionType::cases()))
                ->native(false)
                ->required(),

            TextInput::make('price')
                ->numeric()
                ->prefix('$'),

            Select::make('status')
                ->options(self::enumOptions(ListingStatus::cases()))
                ->native(false)
                ->required(),

            Textarea::make('looking_for')
                ->columnSpanFull(),

            Toggle::make('is_flagged')
                ->label('Flagged for review')
                ->live(),

            Textarea::make('flagged_reason')
                ->label('Flag reason')
                ->visible(fn ($get) => (bool) $get('is_flagged'))
                ->maxLength(1000)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('title')
                    ->searchable()
                    ->limit(40),

                TextColumn::make('user.name')
                    ->label('Owner')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('listing_type')
                    ->badge()
                    ->formatStateUsing(fn (ListingType $state) => $state->label()),

                TextColumn::make('transaction_type')
                    ->badge()
                    ->color('gray')
                    ->formatStateUsing(fn (TransactionType $state) => $state->label()),

                TextColumn::make('status')
                    ->badge()
                    ->color(fn (ListingStatus $state) => match ($state) {
                        ListingStatus::Active => 'success',
                        ListingStatus::Reserved => 'warning',
                        ListingStatus::Completed => 'gray',
                        ListingStatus::Deleted => 'danger',
                    })
                    ->formatStateUsing(fn (ListingStatus $state) => $state->label()),

                IconColumn::make('is_flagged')
                    ->label('Flagged')
                    ->boolean()
                    ->trueColor('danger')
                    ->sortable(),

                IconColumn::make('banned_at')
                    ->label('Banned')
                    ->boolean()
                    ->getStateUsing(fn (Listing $record) => $record->banned_at !== null)
                    ->trueColor('danger')
                    ->sortable(),

                TextColumn::make('flagged_reason')
                    ->label('Flag reason')
                    ->limit(50)
                    ->toggleable(),

                TextColumn::make('created_at')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                TernaryFilter::make('is_flagged')
                    ->label('Flagged'),

                SelectFilter::make('status')
                    ->options(self::enumOptions(ListingStatus::cases())),

                SelectFilter::make('listing_type')
                    ->label('Category')
                    ->options(self::enumOptions(ListingType::cases())),
            ])
            ->actions([
                ActionGroup::make([
                    EditAction::make(),

                    Action::make('approve')
                        ->label('Approve')
                        ->icon('heroicon-o-check-circle')
                        ->color('success')
                        ->visible(fn (Listing $record) => $record->is_flagged)
                        ->requiresConfirmation()
                        ->action(fn (Listing $record) => $record->update([
                            'is_flagged' => false,
                            'flagged_reason' => null,
                        ])),

                    Action::make('delete_listing')
                        ->label('Deactivate')
                        ->icon('heroicon-o-eye-slash')
                        ->color('warning')
                        ->visible(fn (Listing $record) => $record->status !== ListingStatus::Deleted && $record->banned_at === null)
                        ->requiresConfirmation()
                        ->modalDescription('This removes the listing from discovery. It is a logical delete: the record and its history are kept, and it can be restored.')
                        ->action(fn (Listing $record) => $record->update(['status' => ListingStatus::Deleted])),

                    Action::make('ban_listing')
                        ->label('Ban permanently')
                        ->icon('heroicon-o-no-symbol')
                        ->color('danger')
                        ->visible(fn (Listing $record) => $record->banned_at === null)
                        ->requiresConfirmation()
                        ->form([
                            Textarea::make('banned_reason')
                                ->label('Reason')
                                ->required()
                                ->maxLength(1000),
                        ])
                        ->action(fn (Listing $record, array $data) => $record->update([
                            'status' => ListingStatus::Deleted,
                            'banned_at' => now(),
                            'banned_reason' => $data['banned_reason'],
                        ])),

                    Action::make('restore_listing')
                        ->label('Restore')
                        ->icon('heroicon-o-arrow-uturn-left')
                        ->color('success')
                        ->visible(fn (Listing $record) => $record->banned_at !== null)
                        ->requiresConfirmation()
                        ->action(fn (Listing $record) => $record->update([
                            'status' => ListingStatus::Active,
                            'banned_at' => null,
                            'banned_reason' => null,
                        ])),

                    Action::make('flag_user')
                        ->label('Flag User')
                        ->icon('heroicon-o-no-symbol')
                        ->color('danger')
                        ->requiresConfirmation()
                        ->modalDescription(fn (Listing $record) => "This suspends {$record->user->name}'s account. They will no longer be able to authenticate against the mobile API.")
                        ->form([
                            Textarea::make('reason')
                                ->label('Reason')
                                ->required()
                                ->maxLength(1000),
                        ])
                        ->action(function (Listing $record, array $data) {
                            $record->user->update([
                                'is_suspended' => true,
                                'suspension_reason' => $data['reason'],
                            ]);
                        }),
                ]),
            ])
            ->defaultSort('is_flagged', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListListings::route('/'),
            'edit' => Pages\EditListing::route('/{record}/edit'),
        ];
    }

    /**
     * @param  array<int, ListingType|TransactionType|ListingStatus>  $cases
     * @return array<string, string>
     */
    private static function enumOptions(array $cases): array
    {
        return collect($cases)->mapWithKeys(fn ($case) => [$case->value => $case->label()])->all();
    }
}
