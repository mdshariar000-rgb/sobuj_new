<?php

namespace App\Enums;

enum GrowingSetup: string
{
    case Balcony = 'balcony';
    case Indoor = 'indoor';
    case Backyard = 'backyard';
    case Rooftop = 'rooftop';
    case CommunityGarden = 'community_garden';
    case Greenhouse = 'greenhouse';
    case Allotment = 'allotment';

    public function label(): string
    {
        return match ($this) {
            self::Balcony => 'Balcony',
            self::Indoor => 'Indoor',
            self::Backyard => 'Backyard',
            self::Rooftop => 'Rooftop',
            self::CommunityGarden => 'Community Garden',
            self::Greenhouse => 'Greenhouse',
            self::Allotment => 'Allotment',
        };
    }
}
