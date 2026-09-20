<?php

namespace App\Services;

use App\Enums\NotificationType;
use App\Models\AppNotification;
use App\Models\DeviceToken;
use App\Models\User;
use App\Services\Push\PushSender;
use Illuminate\Support\Collection;

/**
 * The single place every like/comment/message trigger goes through — writes
 * the in-app inbox row and best-effort pushes to the recipient's devices.
 * A slow/failed FCM call is caught and logged, never allowed to turn into a
 * 500 on the like/comment/message request it's a side effect of (there is
 * no queue worker running in this app's production deployment, so sending
 * happens synchronously rather than being dispatched to a job that would
 * never actually run).
 */
class NotificationService
{
    public function __construct(private readonly PushSender $pushSender) {}

    /**
     * Writes one AppNotification row for $recipient and pushes to their
     * devices. A no-op — no row, no push — when $actor is the same person
     * as $recipient, the single central "never notify yourself" guard so
     * none of the trigger call sites need to duplicate it.
     *
     * @param  array<string, mixed>  $data
     */
    public function notify(
        User $recipient,
        ?User $actor,
        NotificationType $type,
        string $title,
        string $body,
        array $data = [],
    ): ?AppNotification {
        if ($actor !== null && $actor->is($recipient)) {
            return null;
        }

        // A blocked (or blocking) pair never notifies each other.
        if ($actor !== null && $actor->hasBlockRelationWith($recipient)) {
            return null;
        }

        $notification = $this->write($recipient, $actor, $type, $title, $body, $data);

        $this->pushToUser($recipient, $title, $body, $type, $data);

        return $notification;
    }

    /**
     * Same per-recipient semantics as notify(), but batches the push side
     * into a single FCM call across every notified recipient's devices —
     * for a group message fanning out to every other member at once.
     *
     * @param  iterable<User>  $recipients
     * @param  array<string, mixed>  $data
     */
    public function notifyMany(
        iterable $recipients,
        ?User $actor,
        NotificationType $type,
        string $title,
        string $body,
        array $data = [],
    ): void {
        $notifiedIds = [];

        foreach ($recipients as $recipient) {
            if ($actor !== null && ($actor->is($recipient) || $actor->hasBlockRelationWith($recipient))) {
                continue;
            }

            $this->write($recipient, $actor, $type, $title, $body, $data);
            $notifiedIds[] = $recipient->id;
        }

        if ($notifiedIds === []) {
            return;
        }

        $tokens = DeviceToken::query()->whereIn('user_id', $notifiedIds)->pluck('token');
        $this->push($tokens, $title, $body, $type, $data);
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function write(User $recipient, ?User $actor, NotificationType $type, string $title, string $body, array $data): AppNotification
    {
        $notification = new AppNotification;
        $notification->recipient_id = $recipient->id;
        $notification->actor_id = $actor?->id;
        $notification->type = $type;
        $notification->title = $title;
        $notification->body = $body;
        $notification->data = $data;
        $notification->save();

        return $notification;
    }

    /**
     * @param  array<string, mixed>  $data
     */
    private function pushToUser(User $recipient, string $title, string $body, NotificationType $type, array $data): void
    {
        $tokens = DeviceToken::query()->where('user_id', $recipient->id)->pluck('token');
        $this->push($tokens, $title, $body, $type, $data);
    }

    /**
     * @param  Collection<int, string>  $tokens
     * @param  array<string, mixed>  $data
     */
    private function push(Collection $tokens, string $title, string $body, NotificationType $type, array $data): void
    {
        if ($tokens->isEmpty()) {
            return;
        }

        // FCM's data payload requires every value to be a string.
        $stringData = ['type' => $type->value, ...array_map('strval', $data)];

        try {
            $invalidTokens = $this->pushSender->sendToTokens($tokens->all(), $title, $body, $stringData);

            if ($invalidTokens !== []) {
                DeviceToken::query()->whereIn('token', $invalidTokens)->delete();
            }
        } catch (\Throwable $e) {
            report($e);
        }
    }
}
