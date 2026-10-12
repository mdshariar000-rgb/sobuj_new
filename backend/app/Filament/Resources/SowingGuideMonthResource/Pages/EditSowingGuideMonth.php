<?php

namespace App\Filament\Resources\SowingGuideMonthResource\Pages;

use App\Filament\Resources\SowingGuideMonthResource;
use Filament\Resources\Pages\EditRecord;

class EditSowingGuideMonth extends EditRecord
{
    protected static string $resource = SowingGuideMonthResource::class;

    public function getTitle(): string
    {
        return 'Edit '.$this->getRecord()->monthName();
    }
}
