<?php

namespace App\Services;

use App\Enums\GroupMemberRole;
use App\Models\AiMessage;
use App\Models\Event;
use App\Models\Group;
use App\Models\GroupMessage;
use App\Models\ListingPhoto;
use App\Models\Message;
use App\Models\Post;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Permanently deletes an account and the personal data attached to it (App Store
 * Guideline 5.1.1(v)). Most rows go via the users table's ON DELETE CASCADE foreign
 * keys; this service handles what those can't: cancelling a live Stripe subscription,
 * handing shared groups to another member instead of destroying them for everyone,
 * removing chat messages (which would otherwise survive with a null sender), and
 * deleting the uploaded files from disk.
 */
class AccountDeletionService
{
    public function __construct(private readonly ImageService $imageService) {}

    /**
     * @throws \Throwable if the Stripe subscription can't be cancelled — the account
     *                    is left untouched so the user isn't deleted while still billed.
     */
    public function delete(User $user): void
    {
        // Outside the DB transaction: an external call that must succeed first.
        $subscription = $user->subscription('default');
        if ($subscription !== null && ! $subscription->ended()) {
            $subscription->cancelNow();
        }

        $filePaths = $this->collectFilePaths($user);

        DB::transaction(function () use ($user) {
            $this->handOverOwnedGroups($user);

            Message::query()->where('sender_id', $user->id)->delete();
            GroupMessage::query()->where('sender_id', $user->id)->delete();

            // Cashier's tables have no foreign key to users, so nothing cascades.
            $subscriptionIds = DB::table('subscriptions')->where('user_id', $user->id)->pluck('id');
            DB::table('subscription_items')->whereIn('subscription_id', $subscriptionIds)->delete();
            DB::table('subscriptions')->whereIn('id', $subscriptionIds)->delete();

            $user->tokens()->delete();
            $user->delete();
        });

        foreach ($filePaths as $path) {
            $this->imageService->delete($path);
        }
    }

    /**
     * A group the user created but still has other members would be deleted for all of
     * them by the created_by cascade. Give it to another admin (else the longest-standing
     * member) instead; a group with nobody else in it is simply left to cascade away.
     */
    private function handOverOwnedGroups(User $user): void
    {
        Group::query()->where('created_by', $user->id)->each(function (Group $group) use ($user) {
            $successor = $group->members()
                ->where('users.id', '!=', $user->id)
                ->orderByRaw('group_members.role = ? desc', [GroupMemberRole::Admin->value])
                ->orderBy('group_members.joined_at')
                ->first();

            if ($successor === null) {
                return;
            }

            $group->members()->updateExistingPivot($successor->id, ['role' => GroupMemberRole::Admin]);
            $group->created_by = $successor->id;
            $group->save();
        });
    }

    /**
     * Gathered before the rows disappear; files are only removed after the database
     * delete has committed, so a rolled-back deletion never loses anyone's photos.
     *
     * @return list<string>
     */
    private function collectFilePaths(User $user): array
    {
        $paths = collect([$user->avatar_path, $user->cover_photo_path]);

        $paths = $paths
            ->merge(Post::query()->where('author_id', $user->id)->whereNotNull('image_path')->pluck('image_path'))
            ->merge(ListingPhoto::query()
                ->whereIn('listing_id', $user->listings()->select('id'))
                ->pluck('path'))
            ->merge(Event::query()->where('host_id', $user->id)->whereNotNull('cover_image_path')->pluck('cover_image_path'))
            ->merge(Message::query()->where('sender_id', $user->id)->whereNotNull('image_path')->pluck('image_path'))
            ->merge(GroupMessage::query()->where('sender_id', $user->id)->whereNotNull('image_path')->pluck('image_path'))
            ->merge(AiMessage::query()
                ->whereIn('conversation_id', $user->aiConversations()->select('id'))
                ->whereNotNull('image_path')
                ->pluck('image_path'));

        return $paths->filter()->unique()->values()->all();
    }
}
