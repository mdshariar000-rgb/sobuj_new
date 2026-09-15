<?php

namespace App\Filament\Widgets;

use App\Enums\ListingStatus;
use App\Enums\SwapOfferStatus;
use App\Models\Listing;
use App\Models\SwapOffer;
use App\Models\User;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class StatsOverviewWidget extends BaseWidget
{
    protected function getStats(): array
    {
        return [
            Stat::make('Total Active Users', User::query()->where('is_suspended', false)->count())
                ->description('Accounts not currently suspended')
                ->icon('heroicon-o-users')
                ->color('success'),

            Stat::make('Completed Swaps', SwapOffer::query()->where('status', SwapOfferStatus::Completed)->count())
                ->description('Swap offers that reached completion')
                ->icon('heroicon-o-arrow-path-rounded-square')
                ->color('primary'),

            Stat::make('Active Listings', Listing::query()->where('status', ListingStatus::Active)->count())
                ->description('Listings currently discoverable')
                ->icon('heroicon-o-rectangle-stack')
                ->color('warning'),
        ];
    }
}
