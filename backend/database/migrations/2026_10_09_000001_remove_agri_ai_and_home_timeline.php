<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Removes two retired features and their data (take a database backup
 * before running this on production — it can't be undone):
 *
 * - Agri-AI: the assistant's chats and the Premium subscription records
 *   (Laravel Cashier's tables and its columns on users), and the Gemini /
 *   Stripe keys saved from the admin Settings page.
 * - The personal Home timeline: every post not in a group (their comments
 *   and likes go with them), reshares, post categories, and the reports and
 *   notifications that pointed at those posts.
 *
 * Refuses to run while any subscription is still live in Stripe: deleting
 * the record wouldn't stop Stripe charging that person. Cancel it in the
 * Stripe dashboard first.
 */
return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('subscriptions')) {
            $live = DB::table('subscriptions')
                ->whereIn('stripe_status', ['active', 'trialing', 'past_due', 'incomplete'])
                ->where(fn ($query) => $query->whereNull('ends_at')->orWhere('ends_at', '>', now()))
                ->count();

            if ($live > 0) {
                throw new RuntimeException(
                    "{$live} Agri-AI subscription(s) are still live in Stripe. Cancel them in the Stripe dashboard, then run this again."
                );
            }
        }

        // --- the personal timeline -------------------------------------
        $timelinePostIds = DB::table('posts')->whereNull('group_id')->pluck('id');

        foreach ($timelinePostIds->chunk(500) as $chunk) {
            DB::table('reports')->where('target_type', 'post')->whereIn('target_id', $chunk)->delete();
            DB::table('reports')->where('target_type', 'comment')->whereIn(
                'target_id',
                DB::table('comments')->whereIn('post_id', $chunk)->select('id'),
            )->delete();
        }

        // Notifications that deep-link to one of those posts, plus every
        // "shared your post" notification.
        DB::table('app_notifications')->where('type', 'post_shared')->delete();
        if ($timelinePostIds->isNotEmpty()) {
            $gone = $timelinePostIds->flip();
            DB::table('app_notifications')
                ->whereNotNull('data')
                ->orderBy('id')
                ->select(['id', 'data'])
                ->chunkById(500, function ($rows) use ($gone) {
                    $ids = $rows
                        ->filter(fn ($row) => isset(json_decode((string) $row->data, true)['post_id'])
                            && $gone->has(json_decode((string) $row->data, true)['post_id']))
                        ->pluck('id');
                    DB::table('app_notifications')->whereIn('id', $ids)->delete();
                });
        }

        // Comments and likes cascade with their post.
        foreach ($timelinePostIds->chunk(500) as $chunk) {
            DB::table('posts')->whereIn('id', $chunk)->delete();
        }

        Schema::table('posts', function (Blueprint $table) {
            $table->dropConstrainedForeignId('shared_post_id');
            $table->dropColumn(['is_share', 'category']);
        });
        Schema::dropIfExists('post_categories');

        // --- Agri-AI ---------------------------------------------------
        Schema::dropIfExists('ai_messages');
        Schema::dropIfExists('ai_conversations');
        Schema::dropIfExists('subscription_items');
        Schema::dropIfExists('subscriptions');

        Schema::table('users', function (Blueprint $table) {
            $table->dropIndex(['stripe_id']);
            $table->dropColumn(['stripe_id', 'pm_type', 'pm_last_four', 'trial_ends_at']);
        });

        DB::table('settings')->whereIn('key', [
            'gemini_api_key',
            'stripe_publishable_key',
            'stripe_secret_key',
            'stripe_webhook_secret',
            'stripe_price_id_monthly',
            'stripe_price_id_annual',
            'stripe_monthly_price_usd',
            'stripe_annual_price_usd',
        ])->delete();
    }

    public function down(): void
    {
        // Deliberately one-way: the removed data can only come back from the
        // database backup taken before this ran.
    }
};
