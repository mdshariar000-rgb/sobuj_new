<?php

namespace App\Services;

use App\Models\Setting;
use Laravel\Cashier\Cashier;

/**
 * Lets an admin change the Agri-AI Premium price by typing a real dollar
 * amount in the Settings page — this service does the Stripe API work
 * (create a Product once, then a new Price per change) so the admin never
 * has to open the Stripe Dashboard themselves. Existing subscribers keep
 * their original Price until they renew onto the new one — that's correct,
 * expected Stripe behavior (Prices are immutable), not something to work
 * around.
 */
class StripePriceService
{
    /**
     * Creates a new Stripe Price for the given interval/amount under a
     * Product that's created once and remembered in Settings, and returns
     * the new Price's id. Does not touch the old Price — Stripe Prices are
     * archival, not editable in place.
     */
    public function updatePrice(string $interval, float $amountUsd): string
    {
        $productId = $this->ensureProduct();

        $price = Cashier::stripe()->prices->create([
            'product' => $productId,
            'unit_amount' => (int) round($amountUsd * 100),
            'currency' => 'usd',
            'recurring' => ['interval' => $interval],
        ]);

        return $price->id;
    }

    private function ensureProduct(): string
    {
        $existing = Setting::get('stripe_product_id');
        if ($existing) {
            return $existing;
        }

        $product = Cashier::stripe()->products->create([
            'name' => 'Shobuj Agri-AI Premium',
        ]);

        Setting::set('stripe_product_id', $product->id);

        return $product->id;
    }
}
