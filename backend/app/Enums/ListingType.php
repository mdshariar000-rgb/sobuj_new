<?php

namespace App\Enums;

enum ListingType: string
{
    case SeedsScions = 'seeds_scions';
    case LivePlants = 'live_plants';
    case OrganicFertilizers = 'organic_fertilizers';
    case FarmTools = 'farm_tools';
    case HarvestProduce = 'harvest_produce';
    case CompostSoils = 'compost_soils';

    public function label(): string
    {
        return match ($this) {
            self::SeedsScions => 'Seeds & Scions',
            self::LivePlants => 'Live Plants & Saplings',
            self::OrganicFertilizers => 'Organic Fertilizers',
            self::FarmTools => 'Farm Tools & Equipment',
            self::HarvestProduce => 'Harvest & Produce',
            self::CompostSoils => 'Compost & Soils',
        };
    }
}
