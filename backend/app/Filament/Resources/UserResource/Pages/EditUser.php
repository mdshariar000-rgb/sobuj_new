<?php

namespace App\Filament\Resources\UserResource\Pages;

use App\Filament\Resources\UserResource;
use Filament\Resources\Pages\EditRecord;

class EditUser extends EditRecord
{
    protected static string $resource = UserResource::class;

    /**
     * No hard-delete action here: a User row cascades to delete every listing, swap
     * offer, and message they're party to (see the FK constraints in Phase 1's
     * migrations). Suspension (a table row action on the index page) is the intended
     * moderation lever, not permanent deletion.
     */
    protected function getHeaderActions(): array
    {
        return [];
    }
}
