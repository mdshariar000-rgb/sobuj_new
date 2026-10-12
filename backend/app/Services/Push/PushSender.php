<?php

namespace App\Services\Push;

/**
 * Thin seam between NotificationService and whatever actually delivers a
 * push — lets tests substitute a fake instead of ever calling real Firebase,
 * so the automated suite never sends a real push.
 */
interface PushSender
{
    /**
     * @param  list<string>  $tokens
     * @param  array<string, string>  $data
     * @return list<string> tokens FCM reports invalid/unregistered, for the
     *                      caller to prune from device_tokens
     */
    public function sendToTokens(array $tokens, string $title, string $body, array $data): array;
}
