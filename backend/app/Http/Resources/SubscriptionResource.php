<?php

namespace App\Http\Resources;

use App\Models\Setting;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Wraps the authenticated user's "default" Cashier subscription (or its
 * absence) for the mobile paywall/chat gate and the Manage Subscription
 * screen. There is deliberately no `AgriAiSubscription` model of our own —
 * Cashier's own `subscriptions` table (kept in sync by Stripe webhooks) is
 * the single source of truth.
 *
 * @mixin User
 */
class SubscriptionResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $subscription = $this->subscription('default');

        return [
            'has_access' => $this->hasAgriAiAccess(),
            'plan' => $subscription === null ? null : $this->planLabel($subscription->stripe_price),
            'status' => $subscription?->stripe_status,
            'on_trial' => $subscription?->onTrial() ?? false,
            'trial_ends_at' => $subscription?->trial_ends_at?->toIso8601String(),
            'cancel_at_period_end' => $subscription !== null && $subscription->ends_at !== null,
            'renews_at' => $subscription?->currentPeriodEnd()?->toIso8601String(),
            'ends_at' => $subscription?->ends_at?->toIso8601String(),
        ];
    }

    private function planLabel(?string $stripePriceId): ?string
    {
        if ($stripePriceId === null) {
            return null;
        }

        return match ($stripePriceId) {
            Setting::get('stripe_price_id_monthly') => 'monthly',
            Setting::get('stripe_price_id_annual') => 'annual',
            default => null,
        };
    }
}
