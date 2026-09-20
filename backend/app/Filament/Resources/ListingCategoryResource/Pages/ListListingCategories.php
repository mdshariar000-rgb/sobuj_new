<?php

namespace App\Filament\Resources\ListingCategoryResource\Pages;

use App\Filament\Resources\ListingCategoryResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListListingCategories extends ListRecords
{
    protected static string $resource = ListingCategoryResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
