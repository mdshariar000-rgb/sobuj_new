<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\GroupStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\GroupResource;
use App\Http\Resources\ListingResource;
use App\Http\Resources\UserResource;
use App\Models\Group;
use App\Models\Listing;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * Home's "Search for items, location or members" bar. Each search is saved
 * to the user's history, which drives "Picked for you" (see
 * FeedMarketplaceController::forYou()). suggest() powers the
 * suggestions shown while typing and saves nothing.
 */
class SearchController extends Controller
{
    private const LIMIT = 20;

    /** How many past searches a user keeps. */
    private const HISTORY_SIZE = 20;

    /** How many items, members and groups suggest() returns of each. */
    private const SUGGEST_LIMIT = 3;

    /** How many search terms suggest() returns. */
    private const SUGGEST_TERMS = 6;

    public function search(Request $request): JsonResponse
    {
        $data = $request->validate(['q' => ['required', 'string', 'min:2', 'max:100']]);
        $term = trim($data['q']);
        $viewer = $request->user();

        $this->remember($viewer, $term);

        return response()->json([
            'data' => [
                'listings' => ListingResource::collection($this->listings($viewer, $term, self::LIMIT))->resolve($request),
                'members' => UserResource::collection($this->members($viewer, $term, self::LIMIT))->resolve($request),
                'groups' => GroupResource::collection($this->groups($viewer, $term, self::LIMIT))->resolve($request),
            ],
        ]);
    }

    /**
     * Suggestions while the user types: search terms to complete to (their
     * own past searches, item names and towns), plus the top few items,
     * members and groups to jump straight to.
     */
    public function suggest(Request $request): JsonResponse
    {
        $data = $request->validate(['q' => ['required', 'string', 'min:1', 'max:100']]);
        $term = trim($data['q']);
        $viewer = $request->user();

        if ($term === '') {
            return response()->json(['data' => ['terms' => [], 'listings' => [], 'members' => [], 'groups' => []]]);
        }

        return response()->json([
            'data' => [
                'terms' => $this->suggestedTerms($viewer, $term),
                'listings' => ListingResource::collection($this->listings($viewer, $term, self::SUGGEST_LIMIT))->resolve($request),
                'members' => UserResource::collection($this->members($viewer, $term, self::SUGGEST_LIMIT))->resolve($request),
                'groups' => GroupResource::collection($this->groups($viewer, $term, self::SUGGEST_LIMIT))->resolve($request),
            ],
        ]);
    }

    /** The user's recent searches, newest first. */
    public function history(Request $request): JsonResponse
    {
        return response()->json([
            'data' => $request->user()->searchHistories()
                ->latest('updated_at')
                ->limit(self::HISTORY_SIZE)
                ->pluck('term'),
        ]);
    }

    public function clearHistory(Request $request): JsonResponse
    {
        $request->user()->searchHistories()->delete();

        return response()->json(['message' => 'Search history cleared.']);
    }

    /** Items by what they are, or by where the seller is. */
    private function listings(User $viewer, string $term, int $limit): Collection
    {
        $like = $this->like($term);
        $coordinates = $viewer->getExactCoordinates();

        return Listing::query()
            ->browsableBy($viewer)
            ->where(fn (Builder $query) => $query
                ->search($term)
                ->orWhereHas('user', fn (Builder $query) => $query->where('location_label', 'like', $like)))
            ->when($coordinates !== null, fn ($query) => $query
                ->nearby($coordinates['latitude'], $coordinates['longitude'], PHP_INT_MAX))
            ->reorder('listings.created_at', 'desc')
            ->limit($limit)
            ->get();
    }

    /** Members by name, username or place — names starting with the term first. */
    private function members(User $viewer, string $term, int $limit): Collection
    {
        $like = $this->like($term);

        return User::query()
            ->whereKeyNot($viewer->id)
            ->whereNotIn('users.id', $viewer->hiddenUserIds())
            ->where('is_suspended', false)
            ->where(fn (Builder $query) => $query
                ->where('name', 'like', $like)
                ->orWhere('username', 'like', $like)
                ->orWhere('location_label', 'like', $like))
            ->orderByRaw('name like ? desc', [$this->prefix($term)])
            ->orderBy('name')
            ->limit($limit)
            ->get();
    }

    /**
     * Location groups are named after their town, so a place search finds
     * them too.
     */
    private function groups(User $viewer, string $term, int $limit): Collection
    {
        $like = $this->like($term);

        return Group::query()
            ->listed()
            ->where('status', GroupStatus::Active)
            ->where(fn (Builder $query) => $query
                ->where('name', 'like', $like)
                ->orWhere('description', 'like', $like))
            ->withCount('members')
            ->withExists(['members as is_member' => fn ($query) => $query->where('user_id', $viewer->id)])
            ->orderByRaw('name like ? desc', [$this->prefix($term)])
            ->orderByDesc('members_count')
            ->limit($limit)
            ->get();
    }

    /**
     * Terms to complete the search to: the user's own matching past
     * searches, then names of items for sale/swap, then towns — each
     * tagged with where it came from, without duplicates.
     *
     * @return list<array{text: string, type: string}>
     */
    private function suggestedTerms(User $viewer, string $term): array
    {
        $like = $this->like($term);
        $prefix = $this->prefix($term);

        $history = $viewer->searchHistories()
            ->where('term', 'like', $like)
            ->latest('updated_at')
            ->limit(3)
            ->pluck('term')
            ->map(fn (string $text) => ['text' => $text, 'type' => 'history']);

        $items = Listing::query()
            ->browsableBy($viewer)
            ->where('listings.title', 'like', $like)
            ->reorder()
            ->orderByRaw('listings.title like ? desc', [$prefix])
            ->latest('listings.created_at')
            ->limit(20)
            ->pluck('listings.title')
            ->map(fn (string $text) => ['text' => $text, 'type' => 'item']);

        $places = User::query()
            ->where('address_city', 'like', $prefix)
            ->where('is_suspended', false)
            ->distinct()
            ->orderBy('address_city')
            ->limit(2)
            ->pluck('address_city')
            ->map(fn (string $text) => ['text' => $text, 'type' => 'place']);

        return $history->concat($items)->concat($places)
            ->unique(fn (array $suggestion) => mb_strtolower(trim($suggestion['text'])))
            ->take(self::SUGGEST_TERMS)
            ->values()
            ->all();
    }

    private function like(string $term): string
    {
        return '%'.$this->escape($term).'%';
    }

    private function prefix(string $term): string
    {
        return $this->escape($term).'%';
    }

    private function escape(string $term): string
    {
        return str_replace(['%', '_'], ['\\%', '\\_'], $term);
    }

    private function remember(User $viewer, string $term): void
    {
        $viewer->searchHistories()->updateOrCreate(['term' => mb_strtolower($term)])->touch();

        $keep = $viewer->searchHistories()->latest('updated_at')->limit(self::HISTORY_SIZE)->pluck('id');
        $viewer->searchHistories()->whereNotIn('id', $keep)->delete();
    }
}
