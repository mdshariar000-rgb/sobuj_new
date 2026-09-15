<?php

namespace App\Filament\Resources\ListingResource\Pages;

use App\Filament\Resources\ListingResource;
use Filament\Resources\Pages\EditRecord;

class EditListing extends EditRecord
{
    protected static string $resource = ListingResource::class;

    /**
     * No hard-delete action here: listings are logically deleted (status -> Deleted,
     * see ListingResource's "Delete" row action) so history referenced by swap offers
     * and messages survives. A real DeleteAction would bypass that and cascade-remove
     * the row's swap offers/messages entirely.
     */
    protected function getHeaderActions(): array
    {
        return [];
    }
}
