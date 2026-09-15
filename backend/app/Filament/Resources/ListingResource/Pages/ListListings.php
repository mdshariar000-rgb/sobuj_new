<?php

namespace App\Filament\Resources\ListingResource\Pages;

use App\Filament\Resources\ListingResource;
use Filament\Resources\Pages\ListRecords;

class ListListings extends ListRecords
{
    protected static string $resource = ListingResource::class;

    /**
     * No create action: listings are created by users through the mobile app, not by
     * admins. See ListingResource::canCreate().
     */
    protected function getHeaderActions(): array
    {
        return [];
    }
}
