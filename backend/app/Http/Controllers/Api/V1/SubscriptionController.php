<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\Subscription\StoreSubscriptionRequest;
use App\Http\Resources\SubscriptionResource;
use App\Models\Setting;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Laravel\Cashier\Exceptions\IncompletePayment;

class SubscriptionController extends Controller
{
    /**
     * The signed-in user's Agri-AI Premium subscription status — backs the
     * paywall gate, the chat screen's unlock check, and the Manage
     * Subscription view.
     */
    public function show(Request $request): SubscriptionResource
    {
        return new SubscriptionResource($request->user());
    }

    /**
     * Starts a 7-day-trial Agri-AI Premium subscription using a Stripe
     * PaymentMethod already tokenized on-device by the mobile app (card
     * details never pass through this server). May require completing 3-D
     * Secure — see the 202 branch below.
     */
    public function store(StoreSubscriptionRequest $request): JsonResponse
    {
        $user = $request->user();
        $data = $request->validated();

        $priceId = Setting::get(
            $data['plan'] === 'monthly' ? 'stripe_price_id_monthly' : 'stripe_price_id_annual',
        );

        if (blank($priceId)) {
            return response()->json([
                'message' => 'Subscription plans are not configured yet. Please try again shortly.',
            ], 503);
        }

        try {
            $user->newSubscription('default', $priceId)
                ->trialDays(7)
                ->create($data['payment_method']);
        } catch (IncompletePayment $exception) {
            // The card needs an extra confirmation step (3-D Secure) before the
            // subscription can be finalized — the mobile app completes this via
            // flutter_stripe's handleNextAction() using this client secret, then
            // the subscription becomes active automatically once Stripe confirms
            // it (no need to call this endpoint again).
            return response()->json([
                'requires_action' => true,
                'payment_intent_client_secret' => $exception->payment->clientSecret(),
            ], 202);
        }

        return (new SubscriptionResource($user->fresh()))
            ->response()
            ->setStatusCode(201);
    }

    /**
     * Cancels at the end of the current paid (or trial) period — the user
     * keeps access until then, matching the "Cancel anytime" copy in the
     * paywall design rather than revoking access immediately.
     */
    public function destroy(Request $request): SubscriptionResource
    {
        $user = $request->user();
        $subscription = $user->subscription('default');

        if ($subscription !== null && ! $subscription->canceled()) {
            $subscription->cancel();
        }

        return new SubscriptionResource($user->fresh());
    }
}
