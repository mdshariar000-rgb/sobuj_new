<?php

namespace Database\Seeders;

use App\Enums\EventAttendeeStatus;
use App\Enums\EventFormat;
use App\Enums\EventStatus;
use App\Enums\ExperienceLevel;
use App\Enums\GroupMemberRole;
use App\Enums\GrowingSetup;
use App\Models\Comment;
use App\Models\Event;
use App\Models\Group;
use App\Models\Post;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\Hash;

/**
 * Populates the local dev database with enough realistic Agro Hub content
 * (groups, posts, comments, events) to explore the app
 * with — not used in tests (they run against `shobuj_testing`, a separate
 * database via .env.testing) and never run against production.
 *
 * Re-runnable: clears prior demo rows first rather than accumulating dupes
 * on repeat runs. Log in as demo@agrohub.test / password to see it all as
 * the "you" account — a member of some groups, host/attendee of some
 * events.
 */
class AgroHubDemoSeeder extends Seeder
{
    public function run(): void
    {
        $this->command?->info('Clearing prior demo data...');
        User::query()->where('email', 'like', '%@agrohub.test')->delete();

        $password = Hash::make('password');

        $demo = User::factory()->create([
            'name' => 'Demo Grower',
            'email' => 'demo@agrohub.test',
            'password' => $password,
            'email_verified_at' => now(),
            'experience_level' => ExperienceLevel::Intermediate,
            'growing_setup' => GrowingSetup::Rooftop,
        ]);

        $others = collect([
            ['name' => 'Rina Chowdhury', 'experience' => ExperienceLevel::Expert, 'setup' => GrowingSetup::Backyard],
            ['name' => 'Tanvir Ahmed', 'experience' => ExperienceLevel::Experienced, 'setup' => GrowingSetup::CommunityGarden],
            ['name' => 'Nusrat Jahan', 'experience' => ExperienceLevel::Beginner, 'setup' => GrowingSetup::Balcony],
            ['name' => 'Kamal Hossain', 'experience' => ExperienceLevel::Experienced, 'setup' => GrowingSetup::Greenhouse],
            ['name' => 'Farida Yasmin', 'experience' => ExperienceLevel::Intermediate, 'setup' => GrowingSetup::Indoor],
            ['name' => 'Shakil Rahman', 'experience' => ExperienceLevel::Beginner, 'setup' => GrowingSetup::Rooftop],
            ['name' => 'Mim Akter', 'experience' => ExperienceLevel::Intermediate, 'setup' => GrowingSetup::Balcony],
            ['name' => 'Arif Hasan', 'experience' => ExperienceLevel::Expert, 'setup' => GrowingSetup::Backyard],
        ])->map(fn (array $attrs, int $i) => User::factory()->create([
            'name' => $attrs['name'],
            'email' => strtolower(str_replace(' ', '.', $attrs['name'])).'@agrohub.test',
            'password' => $password,
            'email_verified_at' => now(),
            'experience_level' => $attrs['experience'],
            'growing_setup' => $attrs['setup'],
        ]));

        $everyone = $others->push($demo);

        $this->command?->info('Creating groups...');

        $groupDefs = [
            ['name' => 'Tomato Growers BD', 'category' => 'Crop Type', 'description' => 'Everything tomatoes — varieties, blight, staking, and swapping seedlings across Dhaka.'],
            ['name' => 'Urban Balcony Gardening', 'category' => 'Technique', 'description' => 'Growing food and flowers in small spaces — containers, vertical setups, and sun-hacking for apartment balconies.'],
            ['name' => 'Organic Pest Control', 'category' => 'Technique', 'description' => 'Neem oil, companion planting, and other non-chemical ways to keep pests off your plants.'],
            ['name' => 'Rooftop Farmers BD', 'category' => 'Region', 'description' => 'For growers turning Dhaka rooftops into working gardens — soil weight, drainage, and irrigation on a roof.'],
            ['name' => 'Community Garden Network', 'category' => 'Community', 'description' => 'Coordinating shared plots, tool libraries, and volunteer days across neighborhood community gardens.'],
        ];

        $groups = collect($groupDefs)->map(function (array $def, int $i) use ($everyone) {
            $creator = $everyone[$i % $everyone->count()];

            $group = Group::factory()->create([
                'name' => $def['name'],
                'slug' => str($def['name'])->slug(),
                'category' => $def['category'],
                'description' => $def['description'],
                'created_by' => $creator->id,
            ]);

            $group->members()->attach($creator->id, ['role' => GroupMemberRole::Admin, 'joined_at' => now()->subDays(30)]);

            // A handful of other members per group, demo included in a few.
            $memberPool = $everyone->reject(fn ($user) => $user->id === $creator->id)->shuffle();
            foreach ($memberPool->take(4) as $member) {
                $group->members()->attach($member->id, [
                    'role' => GroupMemberRole::Member,
                    'joined_at' => now()->subDays(random_int(1, 25)),
                ]);
            }

            return $group;
        });

        $this->command?->info('Creating posts and comments...');

        $postBodies = [
            'First tomatoes of the season are finally ripening! Cherry variety, grown from cuttings a neighbor gave me.',
            "Anyone else's basil bolting early this year? Trying to figure out if it's the heat or I'm watering wrong.",
            'Started composting kitchen scraps on the balcony three months ago — texture finally looks right. Small wins.',
            'Question for the experienced folks: best time to transplant seedlings into bigger pots without shocking them?',
            'Made a simple drip irrigation setup out of old bottles for while I\'m traveling. Surprisingly it worked.',
            'Picked up some neem oil for the first time — how often are people spraying it, and does it bother pollinators?',
            'Rooftop garden update: the trellis finally held up through the storm last week. Cucumbers are thriving.',
            'Does anyone have luck growing ginger in containers here? Tried once and it barely sprouted.',
        ];

        foreach ($postBodies as $i => $body) {
            $author = $everyone[$i % $everyone->count()];
            $post = Post::factory()->create([
                'author_id' => $author->id,
                // Posts live in groups — there's no personal timeline.
                'group_id' => $groups[$i % $groups->count()]->id,
                'body' => $body,
                'created_at' => now()->subHours(random_int(1, 200)),
            ]);

            $commenters = $everyone->reject(fn ($user) => $user->id === $author->id)->shuffle()->take(random_int(0, 3));
            foreach ($commenters as $commenter) {
                $comment = new Comment(['body' => fake()->randomElement([
                    'This is great, thanks for sharing!',
                    'Following this — dealing with the same thing.',
                    'Try a bit more shade in the afternoon, worked for me.',
                    'Nice! How long did that take to get going?',
                    'Same here, would love an update in a few weeks.',
                ])]);
                $comment->author_id = $commenter->id;
                $post->comments()->save($comment);
            }
        }

        $groupPostBodies = [
            'Welcome everyone! Introduce yourself and tell us what you\'re growing right now.',
            'Sharing a photo-free update: soil pH tested at 6.5 this week, finally in range after adding lime.',
            'Does anyone want to organize a seed swap meetup next month?',
            'Reminder that the shared tool shed is open every Saturday morning.',
        ];

        foreach ($groups as $group) {
            foreach (collect($groupPostBodies)->random(3) as $body) {
                $author = $everyone->random();
                $post = Post::factory()->create([
                    'author_id' => $author->id,
                    'group_id' => $group->id,
                    'body' => $body,
                    'created_at' => now()->subHours(random_int(1, 150)),
                ]);

                foreach ($everyone->shuffle()->take(random_int(0, 2)) as $commenter) {
                    $comment = new Comment(['body' => 'Count me in!']);
                    $comment->author_id = $commenter->id;
                    $post->comments()->save($comment);
                }
            }
        }

        $this->command?->info('Creating events...');

        $eventDefs = [
            ['title' => 'Compost Workshop for Beginners', 'format' => EventFormat::InPerson, 'location' => 'Dhanmondi Community Garden', 'days' => 5],
            ['title' => 'Seed Swap & Potluck', 'format' => EventFormat::InPerson, 'location' => 'Rooftop, House 12, Road 7', 'days' => 12],
            ['title' => 'Intro to Hydroponics (Online Talk)', 'format' => EventFormat::Online, 'location' => null, 'days' => 3],
            ['title' => 'Organic Pest Control Q&A', 'format' => EventFormat::Hybrid, 'location' => 'Uttara Community Center', 'days' => 9],
            ['title' => 'Balcony Garden Tour', 'format' => EventFormat::InPerson, 'location' => 'Gulshan-2', 'days' => 18],
            ['title' => 'Monthly Rooftop Farmers Meetup', 'format' => EventFormat::InPerson, 'location' => 'Banani Rooftop Collective', 'days' => 25],
        ];

        foreach ($eventDefs as $i => $def) {
            $host = $everyone[$i % $everyone->count()];
            $group = $i % 2 === 0 ? $groups->random() : null;

            $event = Event::factory()->create([
                'host_id' => $host->id,
                'group_id' => $group?->id,
                'title' => $def['title'],
                'format' => $def['format'],
                'location' => $def['location'],
                'starts_at' => now()->addDays($def['days'])->setTime(18, 0),
                'ends_at' => now()->addDays($def['days'])->setTime(20, 0),
                'capacity' => fake()->optional(0.6)->numberBetween(10, 50),
                'status' => EventStatus::Published,
            ]);

            foreach ($everyone->shuffle()->take(random_int(2, 6)) as $attendee) {
                $event->attendees()->attach($attendee->id, [
                    'status' => fake()->randomElement([EventAttendeeStatus::Going, EventAttendeeStatus::Interested]),
                    'rsvped_at' => now()->subDays(random_int(1, 10)),
                ]);
            }
        }

        $this->command?->info('Done. Log in as demo@agrohub.test / password.');
    }
}
