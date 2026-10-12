<?php

namespace Tests\Feature\Api;

use App\Enums\GroupMemberRole;
use App\Enums\ListingStatus;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\Listing;
use App\Models\Message;
use App\Models\User;
use App\Services\AccountDeletionService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ChatMultiImageTest extends TestCase
{
    use RefreshDatabase;

    private function startSwapThread(): array
    {
        $listing = Listing::factory()->create(['status' => ListingStatus::Active]);
        $buyer = User::factory()->create();
        Sanctum::actingAs($buyer);

        $offer = $this->postJson("/api/v1/listings/{$listing->id}/swap-offers")->json('data');

        return [$buyer, $offer['id']];
    }

    public function test_a_swap_message_can_carry_several_photos(): void
    {
        Storage::fake('public');
        [, $offerId] = $this->startSwapThread();

        $response = $this->post("/api/v1/swap-offers/{$offerId}/messages", [
            'images' => [
                UploadedFile::fake()->image('one.jpg'),
                UploadedFile::fake()->image('two.jpg'),
                UploadedFile::fake()->image('three.jpg'),
            ],
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.body', null);
        $this->assertCount(3, $response->json('data.image_urls'));
        // Older app builds only read image_url — it's the first photo.
        $this->assertSame($response->json('data.image_urls.0'), $response->json('data.image_url'));

        $message = Message::findOrFail($response->json('data.id'));
        $this->assertCount(3, $message->imagePaths());
        foreach ($message->imagePaths() as $path) {
            Storage::disk('public')->assertExists($path);
        }
    }

    public function test_the_legacy_single_image_field_still_works_and_lists_one_photo(): void
    {
        Storage::fake('public');
        [, $offerId] = $this->startSwapThread();

        $response = $this->post("/api/v1/swap-offers/{$offerId}/messages", [
            'body' => 'Here it is',
            'image' => UploadedFile::fake()->image('plant.jpg'),
        ]);

        $response->assertCreated();
        $this->assertCount(1, $response->json('data.image_urls'));
        $this->assertSame($response->json('data.image_urls.0'), $response->json('data.image_url'));
    }

    public function test_a_text_message_has_no_photos(): void
    {
        [, $offerId] = $this->startSwapThread();

        $response = $this->postJson("/api/v1/swap-offers/{$offerId}/messages", ['body' => 'Hello']);

        $response->assertCreated();
        $response->assertJsonPath('data.image_url', null);
        $response->assertJsonPath('data.image_urls', []);
    }

    public function test_more_than_the_maximum_photos_is_rejected(): void
    {
        Storage::fake('public');
        [, $offerId] = $this->startSwapThread();

        $images = [];
        for ($i = 0; $i <= Message::MAX_IMAGES; $i++) {
            $images[] = UploadedFile::fake()->image("p{$i}.jpg");
        }

        $response = $this->post(
            "/api/v1/swap-offers/{$offerId}/messages",
            ['images' => $images],
            ['Accept' => 'application/json'],
        );

        $response->assertUnprocessable();
        $response->assertJsonValidationErrors(['images']);
    }

    public function test_a_message_sent_before_multi_photo_support_lists_its_single_photo(): void
    {
        $message = Message::factory()->create([
            'image_path' => 'swap-offers/1/old.jpg',
            'image_paths' => null,
        ]);

        $this->assertSame(['swap-offers/1/old.jpg'], $message->imagePaths());
        $this->assertSame('📷 Photo', $message->photoPreviewText());
    }

    public function test_a_group_message_can_carry_several_photos(): void
    {
        Storage::fake('public');
        $group = Group::factory()->create();
        $sender = User::factory()->create();
        $group->members()->attach($sender->id, ['role' => GroupMemberRole::Member, 'joined_at' => now()]);
        Sanctum::actingAs($sender);

        $response = $this->post("/api/v1/groups/{$group->id}/messages", [
            'body' => 'My harvest',
            'images' => [
                UploadedFile::fake()->image('one.jpg'),
                UploadedFile::fake()->image('two.jpg'),
            ],
        ]);

        $response->assertCreated();
        $response->assertJsonPath('data.body', 'My harvest');
        $this->assertCount(2, $response->json('data.image_urls'));

        $message = GroupMessage::findOrFail($response->json('data.id'));
        $this->assertSame('📷 2 photos', $message->photoPreviewText());
    }

    public function test_deleting_an_account_removes_every_photo_of_its_messages(): void
    {
        Storage::fake('public');
        [$buyer, $offerId] = $this->startSwapThread();

        $response = $this->post("/api/v1/swap-offers/{$offerId}/messages", [
            'images' => [
                UploadedFile::fake()->image('one.jpg'),
                UploadedFile::fake()->image('two.jpg'),
            ],
        ]);
        $paths = Message::findOrFail($response->json('data.id'))->imagePaths();

        app(AccountDeletionService::class)->delete($buyer);

        foreach ($paths as $path) {
            Storage::disk('public')->assertMissing($path);
        }
    }
}
