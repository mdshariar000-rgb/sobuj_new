<?php

namespace App\Enums;

enum ListingCondition: string
{
    case NewFresh = 'new_fresh';
    case EstablishedPotted = 'established_potted';
    case LightlyUsed = 'lightly_used';
    case OrganicCertified = 'organic_certified';

    public function label(): string
    {
        return match ($this) {
            self::NewFresh => 'New / Fresh',
            self::EstablishedPotted => 'Established / Potted',
            self::LightlyUsed => 'Lightly Used',
            self::OrganicCertified => 'Organic Certified',
        };
    }
}
