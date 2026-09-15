<?php

namespace App\Filament\Resources\GroupCategoryResource\Pages;

use App\Filament\Resources\GroupCategoryResource;
use Filament\Actions;
use Filament\Resources\Pages\ListRecords;

class ListGroupCategories extends ListRecords
{
    protected static string $resource = GroupCategoryResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\CreateAction::make(),
        ];
    }
}
