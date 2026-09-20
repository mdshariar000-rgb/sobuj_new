<?php

namespace App\Filament\Resources;

use App\Enums\ExperienceLevel;
use App\Enums\GrowingSetup;
use App\Filament\Resources\UserResource\Pages;
use App\Models\User;
use Carbon\Carbon;
use Filament\Forms\Components\DateTimePicker;
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
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class UserResource extends Resource
{
    protected static ?string $model = User::class;

    protected static ?string $navigationIcon = 'heroicon-o-users';

    protected static ?string $navigationLabel = 'Users';

    protected static ?string $navigationGroup = 'Moderation';

    protected static ?int $navigationSort = 2;

    /**
     * Consumer accounts always self-register through the mobile app (which captures
     * the mandatory location — see the users migration's NOT NULL geometry columns —
     * as part of registration). This resource moderates existing accounts; it doesn't
     * fabricate new ones. To provision a staff/admin account, use:
     *   php artisan shobuj:create-admin
     */
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

            TextInput::make('email')
                ->email()
                ->required()
                ->maxLength(255)
                ->unique(ignoreRecord: true),

            Select::make('experience_level')
                ->options(self::enumOptions(ExperienceLevel::cases()))
                ->native(false),

            Select::make('growing_setup')
                ->options(self::enumOptions(GrowingSetup::cases()))
                ->native(false),

            Toggle::make('is_admin')
                ->label('Admin (panel access)')
                ->helperText('Grants access to this admin panel. Only enable for trusted staff.'),

            Toggle::make('is_suspended')
                ->label('Suspended')
                ->live()
                ->helperText('A suspended account cannot authenticate against the mobile API.'),

            DateTimePicker::make('suspended_until')
                ->label('Banned until')
                ->helperText('Leave blank for a permanent ban — see the Ban temporarily/permanently actions for a guided version of this.')
                ->visible(fn ($get) => (bool) $get('is_suspended')),

            Textarea::make('suspension_reason')
                ->label('Suspension reason')
                ->visible(fn ($get) => (bool) $get('is_suspended'))
                ->maxLength(1000)
                ->columnSpanFull(),
        ]);
    }

    public static function table(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn (Builder $query) => $query->withCompletedSwapsCount())
            ->columns([
                TextColumn::make('name')
                    ->searchable()
                    ->sortable(),

                TextColumn::make('email')
                    ->searchable()
                    ->copyable(),

                TextColumn::make('experience_level')
                    ->badge()
                    ->formatStateUsing(fn (?ExperienceLevel $state) => $state?->label())
                    ->toggleable(),

                TextColumn::make('growing_setup')
                    ->badge()
                    ->color('gray')
                    ->formatStateUsing(fn (?GrowingSetup $state) => $state?->label())
                    ->toggleable(),

                TextColumn::make('rating_avg')
                    ->label('Rating')
                    ->numeric(2)
                    ->sortable(),

                TextColumn::make('completed_swaps_count')
                    ->label('Completed swaps')
                    ->numeric()
                    ->sortable()
                    ->alignCenter(),

                IconColumn::make('verified_at')
                    ->label('Verified')
                    ->boolean()
                    ->getStateUsing(fn (User $record) => $record->verified_at !== null)
                    ->sortable(),

                IconColumn::make('is_suspended')
                    ->label('Suspended')
                    ->boolean()
                    ->trueColor('danger')
                    ->falseColor('gray')
                    ->sortable(),

                TextColumn::make('suspension_status')
                    ->label('Ban')
                    ->getStateUsing(fn (User $record) => match (true) {
                        ! $record->is_suspended => 'Active',
                        $record->suspended_until === null => 'Permanently banned',
                        default => 'Banned until '.$record->suspended_until->format('M j, Y'),
                    })
                    ->color(fn (User $record) => match (true) {
                        ! $record->is_suspended => 'gray',
                        $record->suspended_until === null => 'danger',
                        default => 'warning',
                    })
                    ->toggleable(),

                IconColumn::make('is_admin')
                    ->label('Admin')
                    ->boolean()
                    ->toggleable(isToggledHiddenByDefault: true),

                TextColumn::make('agri_ai_subscription')
                    ->label('Agri-AI')
                    ->badge()
                    // Read-only — driven entirely by Cashier's own `subscriptions` table
                    // (kept in sync by Stripe webhooks), never edited directly here.
                    ->getStateUsing(fn (User $record) => $record->subscription('default')?->stripe_status)
                    ->formatStateUsing(fn (?string $state) => match ($state) {
                        'trialing' => 'Trial',
                        'active' => 'Active',
                        null => 'None',
                        default => ucfirst($state),
                    })
                    ->color(fn (User $record) => match (true) {
                        $record->hasAgriAiAccess() => 'success',
                        $record->subscription('default') !== null => 'warning',
                        default => 'gray',
                    }),

                TextColumn::make('created_at')
                    ->label('Joined')
                    ->dateTime()
                    ->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                TernaryFilter::make('is_suspended')
                    ->label('Suspension status'),

                TernaryFilter::make('verified_at')
                    ->label('Verification status')
                    ->queries(
                        true: fn (Builder $query) => $query->whereNotNull('verified_at'),
                        false: fn (Builder $query) => $query->whereNull('verified_at'),
                    )
                    ->trueLabel('Verified')
                    ->falseLabel('Unverified'),
            ])
            ->actions([
                ActionGroup::make([
                    EditAction::make(),

                    Action::make('verify')
                        ->label('Verify')
                        ->icon('heroicon-o-check-badge')
                        ->color('success')
                        ->visible(fn (User $record) => $record->verified_at === null)
                        ->requiresConfirmation()
                        ->action(fn (User $record) => $record->update(['verified_at' => now()])),

                    Action::make('unverify')
                        ->label('Remove verification')
                        ->icon('heroicon-o-x-circle')
                        ->color('gray')
                        ->visible(fn (User $record) => $record->verified_at !== null)
                        ->requiresConfirmation()
                        ->action(fn (User $record) => $record->update(['verified_at' => null])),

                    Action::make('ban_temporarily')
                        ->label('Ban temporarily')
                        ->icon('heroicon-o-clock')
                        ->color('warning')
                        ->visible(fn (User $record) => ! $record->is_suspended)
                        ->requiresConfirmation()
                        ->form([
                            TextInput::make('days')
                                ->label('Days')
                                ->numeric()
                                ->required()
                                ->minValue(1),
                            Textarea::make('suspension_reason')
                                ->label('Reason')
                                ->required()
                                ->maxLength(1000),
                        ])
                        ->action(function (User $record, array $data) {
                            $record->update([
                                'is_suspended' => true,
                                'suspended_until' => Carbon::now()->addDays((int) $data['days']),
                                'suspension_reason' => $data['suspension_reason'],
                            ]);
                        }),

                    Action::make('ban_permanently')
                        ->label('Ban permanently')
                        ->icon('heroicon-o-no-symbol')
                        ->color('danger')
                        ->visible(fn (User $record) => ! $record->is_suspended)
                        ->requiresConfirmation()
                        ->modalDescription('This does not auto-expire. It can still be lifted later via "Unban" if needed.')
                        ->form([
                            Textarea::make('suspension_reason')
                                ->label('Reason')
                                ->required()
                                ->maxLength(1000),
                        ])
                        ->action(function (User $record, array $data) {
                            $record->update([
                                'is_suspended' => true,
                                'suspended_until' => null,
                                'suspension_reason' => $data['suspension_reason'],
                            ]);
                        }),

                    Action::make('unsuspend')
                        ->label('Unban')
                        ->icon('heroicon-o-lock-open')
                        ->color('success')
                        ->visible(fn (User $record) => $record->is_suspended)
                        ->requiresConfirmation()
                        ->action(fn (User $record) => $record->update([
                            'is_suspended' => false,
                            'suspended_until' => null,
                            'suspension_reason' => null,
                        ])),
                ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListUsers::route('/'),
            'edit' => Pages\EditUser::route('/{record}/edit'),
        ];
    }

    /**
     * @param  array<int, ExperienceLevel|GrowingSetup>  $cases
     * @return array<string, string>
     */
    private static function enumOptions(array $cases): array
    {
        return collect($cases)->mapWithKeys(fn ($case) => [$case->value => $case->label()])->all();
    }
}
