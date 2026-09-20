<?php

namespace App\Services\Push;

use Illuminate\Contracts\Container\Container;
use Kreait\Firebase\Contract\Messaging;
use Kreait\Firebase\Messaging\CloudMessage;

class FcmPushSender implements PushSender
{
    public function __construct(private readonly Container $container) {}

    /**
     * Sends one message to every token via a single multicast call, with
     * both a `notification` block (so Android draws a system tray
     * notification even while the app is backgrounded/killed) and a `data`
     * block (for the app to deep-link once tapped/opened). FCM's data
     * payload requires every value to be a string.
     *
     * The `Messaging` contract is resolved here rather than constructor-
     * injected, so building it (which requires valid Firebase credentials)
     * only happens when a push is actually about to be sent — not every
     * time `NotificationService` is resolved for a like/comment/message
     * request. That keeps credential/config failures inside the try/catch
     * in `NotificationService::push()`, instead of blowing up container
     * resolution before that try/catch ever runs (which would 500 every
     * such request until real Firebase credentials are configured).
     *
     * @param  list<string>  $tokens
     * @param  array<string, string>  $data
     * @return list<string>
     */
    public function sendToTokens(array $tokens, string $title, string $body, array $data): array
    {
        $message = CloudMessage::new()
            ->withNotification(['title' => $title, 'body' => $body])
            ->withData($data);

        $report = $this->container->make(Messaging::class)->sendMulticast($message, $tokens);

        return [...$report->invalidTokens(), ...$report->unknownTokens()];
    }
}
