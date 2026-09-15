<?php

namespace App\Filament\Resources\GroupCategoryResource\Pages;

use App\Filament\Resources\GroupCategoryResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditGroupCategory extends EditRecord
{
    protected static string $resource = GroupCategoryResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
