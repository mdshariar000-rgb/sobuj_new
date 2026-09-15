<?php

namespace App\Filament\Resources\BannedSpeciesResource\Pages;

use App\Filament\Resources\BannedSpeciesResource;
use Filament\Actions;
use Filament\Resources\Pages\EditRecord;

class EditBannedSpecies extends EditRecord
{
    protected static string $resource = BannedSpeciesResource::class;

    protected function getHeaderActions(): array
    {
        return [
            Actions\DeleteAction::make(),
        ];
    }
}
