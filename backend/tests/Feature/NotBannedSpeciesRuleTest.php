<?php

namespace Tests\Feature;

use App\Models\BannedSpecies;
use App\Rules\NotBannedSpecies;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Validator;
use Tests\TestCase;

class NotBannedSpeciesRuleTest extends TestCase
{
    use RefreshDatabase;

    public function test_value_containing_a_banned_species_name_fails(): void
    {
        BannedSpecies::factory()->create(['name' => 'Japanese Knotweed']);

        $validator = Validator::make(
            ['title' => 'Fast-growing Japanese Knotweed cuttings, free to a good home'],
            ['title' => [new NotBannedSpecies]],
        );

        $this->assertTrue($validator->fails());
        $this->assertStringContainsString('Japanese Knotweed', $validator->errors()->first('title'));
    }

    public function test_match_is_case_insensitive(): void
    {
        BannedSpecies::factory()->create(['name' => 'Kudzu']);

        $validator = Validator::make(
            ['title' => 'KUDZU vine, huge quantity'],
            ['title' => [new NotBannedSpecies]],
        );

        $this->assertTrue($validator->fails());
    }

    public function test_unrelated_title_passes(): void
    {
        BannedSpecies::factory()->create(['name' => 'Giant Hogweed']);

        $validator = Validator::make(
            ['title' => 'Cherry tomato seeds, heirloom variety'],
            ['title' => [new NotBannedSpecies]],
        );

        $this->assertFalse($validator->fails());
    }

    public function test_very_short_banned_names_do_not_match_everything(): void
    {
        // A 2-character banned entry should be ignored as a substring match, or it
        // would flag almost any listing title containing those two letters.
        BannedSpecies::factory()->create(['name' => 'ivy']);
        BannedSpecies::factory()->create(['name' => 'iv']);

        $validator = Validator::make(
            ['title' => 'Beautiful climbing ivy, well established'],
            ['title' => [new NotBannedSpecies]],
        );

        // Still fails because "ivy" (3 chars) matches; but confirm it wasn't the
        // 2-char "iv" causing unrelated false positives elsewhere.
        $this->assertTrue($validator->fails());

        $unrelated = Validator::make(
            ['title' => 'Live oak sapling'],
            ['title' => [new NotBannedSpecies]],
        );

        $this->assertFalse($unrelated->fails());
    }

    public function test_empty_banned_species_table_never_fails(): void
    {
        $validator = Validator::make(
            ['title' => 'Anything at all'],
            ['title' => [new NotBannedSpecies]],
        );

        $this->assertFalse($validator->fails());
    }
}
