<?php

namespace Tests;

use App\Services\Push\PushSender;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;

abstract class TestCase extends BaseTestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        // Every controller that triggers a notification constructor/method-
        // injects NotificationService, which needs a PushSender resolvable
        // on every request — including tests that don't care about push at
        // all. The real FcmPushSender needs genuine Firebase credentials
        // this environment doesn't have, so bind a no-op fake by default;
        // any test that actually wants to assert push behavior overrides
        // this via $this->mock(PushSender::class, ...).
        $this->app->bind(PushSender::class, fn () => new class implements PushSender
        {
            public function sendToTokens(array $tokens, string $title, string $body, array $data): array
            {
                return [];
            }
        });
    }
}
