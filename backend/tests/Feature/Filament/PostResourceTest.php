<?php

namespace Tests\Feature\Filament;

use App\Filament\Resources\PostResource\Pages\ListPosts;
use App\Models\Post;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Livewire\Livewire;
use Tests\TestCase;

class PostResourceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        $this->actingAs(User::factory()->create(['is_admin' => true]));
    }

    public function test_index_page_lists_posts_from_any_author(): void
    {
        $post = Post::factory()->create(['body' => 'A real post body']);

        Livewire::test(ListPosts::class)
            ->assertSuccessful()
            ->assertCanSeeTableRecords([$post]);
    }

    public function test_deactivate_and_reactivate_toggle_moderation_status(): void
    {
        // ->fresh(): a just-created model doesn't reflect the DB's own
        // column default (moderation_status) until refetched — real usage
        // always queries fresh from the DB, so this matches that.
        $post = Post::factory()->create()->fresh();

        Livewire::test(ListPosts::class)
            ->callTableAction('deactivate', $post, data: ['reason' => 'Off-topic spam'])
            ->assertHasNoTableActionErrors();

        $post->refresh();
        $this->assertSame('deactivated', $post->moderation_status->value);
        $this->assertSame('Off-topic spam', $post->moderation_reason);
        $this->assertNotNull($post->moderated_at);

        Livewire::test(ListPosts::class)
            ->callTableAction('reactivate', $post)
            ->assertHasNoTableActionErrors();

        $post->refresh();
        $this->assertSame('visible', $post->moderation_status->value);
        $this->assertNull($post->moderation_reason);
    }

    public function test_ban_and_restore_toggle_moderation_status(): void
    {
        $post = Post::factory()->create()->fresh();

        Livewire::test(ListPosts::class)
            ->callTableAction('ban', $post, data: ['reason' => 'Prohibited content'])
            ->assertHasNoTableActionErrors();

        $post->refresh();
        $this->assertSame('banned', $post->moderation_status->value);
        $this->assertSame('Prohibited content', $post->moderation_reason);

        Livewire::test(ListPosts::class)
            ->callTableAction('restore', $post)
            ->assertHasNoTableActionErrors();

        $this->assertSame('visible', $post->refresh()->moderation_status->value);
    }
}
