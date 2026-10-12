<?php

namespace App\Http\Controllers;

use App\Enums\ListingStatus;
use App\Models\Listing;
use App\Models\Setting;
use App\Models\User;
use Illuminate\Contracts\View\View;

/**
 * Public landing pages behind the app's Share buttons (/l/{id}, /u/{id}):
 * a small preview of the listing or profile plus links to get the app. They
 * show only what anyone in the app could already see — no location, no
 * contact details — and fall back to a plain "get the app" page for a
 * listing that's no longer live or an account that's suspended.
 */
class SharePageController extends Controller
{
    public function listing(int $id): View
    {
        $listing = Listing::with(['photos', 'user'])->find($id);
        $live = $listing !== null
            && in_array($listing->status, [ListingStatus::Active, ListingStatus::Reserved], true)
            && ! $listing->user?->is_suspended;

        return view('share.page', [
            ...$this->storeLinks(),
            'title' => $live ? $listing->title : null,
            'subtitle' => $live ? $this->listingSubtitle($listing) : null,
            'imageUrl' => $live ? $listing->photos->sortBy('sort_order')->first()?->url() : null,
            'fallback' => 'This listing is no longer available.',
        ]);
    }

    public function user(int $id): View
    {
        $user = User::find($id);
        $visible = $user !== null && ! $user->is_suspended;

        return view('share.page', [
            ...$this->storeLinks(),
            'title' => $visible ? $user->name : null,
            'subtitle' => $visible
                ? ($user->username ? '@'.$user->username.' · ' : '').'on Shobuj'
                : null,
            'imageUrl' => $visible ? $user->avatarUrl() : null,
            'round' => true,
            'fallback' => 'This profile is no longer available.',
        ]);
    }

    private function listingSubtitle(Listing $listing): string
    {
        $price = $listing->price !== null && (float) $listing->price > 0
            ? '£'.number_format((float) $listing->price, 2)
            : ucfirst($listing->transaction_type->value);

        return collect([$price, $listing->listing_type, $listing->user?->name ? 'by '.$listing->user->name : null])
            ->filter()
            ->implode(' · ');
    }

    /**
     * @return array{appStoreUrl: ?string, androidUrl: ?string}
     */
    private function storeLinks(): array
    {
        return [
            'appStoreUrl' => Setting::get('app_store_url'),
            'androidUrl' => Setting::get('android_download_url'),
        ];
    }
}
