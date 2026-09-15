<?php

namespace App\Filament\Resources;

use App\Filament\Resources\SubscriptionResource\Pages;
use App\Models\Setting;
use Filament\Resources\Resource;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Laravel\Cashier\Subscription;

/**
 * A read-only view over Cashier's own `subscriptions` table (kept in sync
 * by Stripe webhooks) — there is deliberately no local Subscription model
 * of our own, same principle as SubscriptionResource (the API resource)
 * and User::hasAgriAiAccess().
 */
class SubscriptionResource extends Resource
{
    protected static ?string $model = Subscription::class;

    protected static ?string $navigationIcon = 'heroicon-o-credit-card';

    protected static ?string $navigationLabel = 'Subscriptions';

    protected static ?string $navigationGroup = 'System';

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canEdit($record): bool
    {
        return false;
    }

    public static function canDelete($record): bool
    {
        return false;
    }

    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                TextColumn::make('user.name')
                    ->label('Subscriber')
                    ->searchable(),

                TextColumn::make('user.email')
                    ->searchable(),

                TextColumn::make('stripe_price')
                    ->label('Plan')
                    ->formatStateUsing(fn (?string $state) => match ($state) {
                        Setting::get('stripe_price_id_monthly') => 'Monthly',
                        Setting::get('stripe_price_id_annual') => 'Annual',
                        default => 'Unknown',
                    }),

                TextColumn::make('stripe_status')
                    ->label('Status')
                    ->badge()
                    ->color(fn (?string $state) => match ($state) {
                        'active' => 'success',
                        'trialing' => 'warning',
                        'canceled', 'incomplete_expired' => 'danger',
                        default => 'gray',
                    }),

                TextColumn::make('trial_ends_at')
                    ->label('Trial ends')
                    ->dateTime()
                    ->placeholder('—'),

                TextColumn::make('ends_at')
                    ->label('Ends')
                    ->dateTime()
                    ->placeholder('—'),

                TextColumn::make('created_at')
                    ->label('Started')
                    ->dateTime()
                    ->sortable(),
            ])
            ->filters([
                SelectFilter::make('stripe_status')
                    ->label('Status')
                    ->options([
                        'trialing' => 'Trialing',
                        'active' => 'Active',
                        'past_due' => 'Past due',
                        'canceled' => 'Canceled',
                        'incomplete' => 'Incomplete',
                        'incomplete_expired' => 'Incomplete (expired)',
                        'unpaid' => 'Unpaid',
                    ]),
            ])
            ->defaultSort('created_at', 'desc');
    }

    public static function getPages(): array
    {
        return [
            'index' => Pages\ListSubscriptions::route('/'),
        ];
    }
}
