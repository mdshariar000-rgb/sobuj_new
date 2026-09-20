<?php

namespace App\Filament\Widgets;

use App\Enums\EventStatus;
use App\Enums\GroupStatus;
use App\Enums\ListingStatus;
use App\Enums\PostModerationStatus;
use App\Enums\ReportStatus;
use App\Enums\SwapOfferStatus;
use App\Filament\Resources\ListingResource;
use App\Filament\Resources\ReportResource;
use App\Models\Event;
use App\Models\Group;
use App\Models\Listing;
use App\Models\Post;
use App\Models\Report;
use App\Models\SwapOffer;
use App\Models\User;
use Filament\Widgets\StatsOverviewWidget as BaseWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

class StatsOverviewWidget extends BaseWidget
{
    protected function getColumns(): int
    {
        return 3;
    }

    protected function getStats(): array
    {
        return [
            // User-filed reports (posts, comments, listings, chat messages, users)
            // — the primary "needs a decision today" queue, and the one App Store
            // review expects to be actively worked.
            Stat::make('Pending Reports', Report::query()->where('status', ReportStatus::Pending)->count())
                ->description('User reports awaiting review')
                ->icon('heroicon-o-exclamation-triangle')
                ->color('danger')
                ->url(ReportResource::getUrl('index')),

            // The one real "go review this" queue on the site — everything
            // else below is a content total, not something waiting on an
            // admin's action today. Links straight to the moderation queue,
            // which already sorts flagged listings first.
            Stat::make('Flagged Listings', Listing::query()->where('is_flagged', true)->count())
                ->description('Reported by users, awaiting review')
                ->icon('heroicon-o-flag')
                ->color('danger')
                ->url(ListingResource::getUrl('index')),

            Stat::make('Total Active Users', User::query()->where('is_suspended', false)->count())
                ->description('Accounts not currently suspended')
                ->icon('heroicon-o-users')
                ->color('success'),

            Stat::make('New Users', User::query()->where('created_at', '>=', now()->subDays(7))->count())
                ->description('Signed up in the last 7 days')
                ->icon('heroicon-o-user-plus')
                ->color('success'),

            Stat::make('Active Groups', Group::query()->where('status', GroupStatus::Active)->count())
                ->description('Not deactivated or banned')
                ->icon('heroicon-o-user-group')
                ->color('primary'),

            Stat::make('Visible Posts', Post::query()->where('moderation_status', PostModerationStatus::Visible)->count())
                ->description('Home Feed + group discussion posts')
                ->icon('heroicon-o-document-text')
                ->color('primary'),

            Stat::make('Upcoming Events', Event::query()
                ->where('status', EventStatus::Published)
                ->where(function ($query) {
                    $query->where('ends_at', '>=', now())
                        ->orWhere(function ($query) {
                            $query->whereNull('ends_at')->where('starts_at', '>=', now());
                        });
                })
                ->count())
                ->description('Published, not yet ended')
                ->icon('heroicon-o-calendar-days')
                ->color('primary'),

            Stat::make('Active Listings', Listing::query()->where('status', ListingStatus::Active)->count())
                ->description('Listings currently discoverable')
                ->icon('heroicon-o-rectangle-stack')
                ->color('warning'),

            Stat::make('Completed Swaps', SwapOffer::query()->where('status', SwapOfferStatus::Completed)->count())
                ->description('Swap offers that reached completion')
                ->icon('heroicon-o-arrow-path-rounded-square')
                ->color('warning'),
        ];
    }
}
