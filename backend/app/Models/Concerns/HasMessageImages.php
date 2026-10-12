<?php

namespace App\Models\Concerns;

use Illuminate\Support\Facades\Storage;

/**
 * Shared by Message and GroupMessage: photos, reply quotes and emoji
 * reactions.
 *
 * A chat message can carry several photos. `image_paths` holds all of them;
 * `image_path` mirrors the first one so older app builds that only know
 * about a single `image_url` still show a photo. Messages sent before
 * `image_paths` existed only have `image_path`, which is treated as a
 * one-photo list.
 */
trait HasMessageImages
{
    /**
     * Most photos one message may carry — enforced by the store requests.
     */
    public const MAX_IMAGES = 10;

    /**
     * The quick reactions offered on a chat message — the only emoji the
     * reaction endpoints accept.
     */
    public const REACTION_EMOJIS = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

    public function initializeHasMessageImages(): void
    {
        // reply_to_id arrives as a string from multipart form input; the
        // cast keeps the API returning it as an integer either way.
        $this->mergeCasts(['image_paths' => 'array', 'reply_to_id' => 'integer']);
        $this->mergeFillable(['image_paths']);
    }

    /**
     * @param  list<string>  $paths
     */
    public function setImagePaths(array $paths): void
    {
        $this->image_path = $paths[0] ?? null;
        $this->image_paths = $paths === [] ? null : array_values($paths);
    }

    /**
     * @return list<string>
     */
    public function imagePaths(): array
    {
        if (! empty($this->image_paths)) {
            return array_values($this->image_paths);
        }

        return $this->image_path !== null ? [$this->image_path] : [];
    }

    /**
     * @return list<string>
     */
    public function imageUrls(): array
    {
        return array_map(
            fn (string $path) => Storage::disk('public')->url($path),
            $this->imagePaths(),
        );
    }

    public function imageUrl(): ?string
    {
        return $this->imageUrls()[0] ?? null;
    }

    /**
     * Push-notification preview for a message with no caption.
     */
    public function photoPreviewText(): string
    {
        $count = count($this->imagePaths());

        return $count > 1 ? "📷 {$count} photos" : '📷 Photo';
    }

    /**
     * The compact quote a reply shows of the message it answers — null when
     * this isn't a reply, or when the original is gone or withheld (its
     * `reply_to_id` is still returned, so the app can say "unavailable").
     *
     * Only call once `replyTo.sender` is loaded.
     *
     * @return array{id: int, body: ?string, sender_name: ?string, image_url: ?string, image_count: int}|null
     */
    public function replyPreview(): ?array
    {
        $original = $this->reply_to_id !== null ? $this->replyTo : null;
        if ($original === null) {
            return null;
        }

        return [
            'id' => $original->id,
            'body' => $original->body,
            'sender_name' => $original->sender?->name,
            'image_url' => $original->imageUrl(),
            'image_count' => count($original->imagePaths()),
        ];
    }

    /**
     * Reactions grouped by emoji, in the order each emoji was first used:
     * `[{emoji, count, user_ids}]`. `user_ids` (rather than a per-viewer
     * "reacted by me" flag) lets the same payload go out over the broadcast
     * channel to everyone, each app working out its own highlight.
     *
     * Only call once `reactions` is loaded.
     *
     * @return list<array{emoji: string, count: int, user_ids: list<int>}>
     */
    public function reactionSummary(): array
    {
        return $this->reactions
            ->sortBy('id')
            ->groupBy('emoji')
            ->map(fn ($reactions, $emoji) => [
                'emoji' => (string) $emoji,
                'count' => $reactions->count(),
                'user_ids' => $reactions->pluck('user_id')->map(fn ($id) => (int) $id)->values()->all(),
            ])
            ->values()
            ->all();
    }
}
