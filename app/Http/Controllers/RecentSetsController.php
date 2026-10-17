<?php

namespace App\Http\Controllers;

use CardTechie\TradingCardApiSdk\Exceptions\TradingCardApiException;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Recently added sets page and its Atom feed (#526).
 *
 * The API exposes no publish date, so "newest" is newest created. Both
 * routes share one cached upstream call.
 */
class RecentSetsController extends Controller
{
    private const CACHE_KEY = 'recent-sets';

    private const CACHE_SECONDS = 600;

    /**
     * Show the recently added sets page.
     *
     * @return \Illuminate\Contracts\View\View
     */
    public function index()
    {
        return view('app.recent-sets', [
            'title' => 'Recently Added Checklists',
            'sets' => $this->recentSets(),
        ]);
    }

    /**
     * Return the Atom feed of recently added sets.
     *
     * @return \Illuminate\Http\Response
     */
    public function feed()
    {
        try {
            $sets = $this->recentSets();
        } catch (TradingCardApiException $e) {
            Log::error('Recent sets feed unavailable', ['message' => $e->getMessage()]);

            return response('The card data service is temporarily unavailable.', 503)
                ->header('Content-Type', 'text/plain; charset=UTF-8');
        }

        $updated = collect($sets)->pluck('created_at')->filter()->first()
            ?? now()->toAtomString();

        // The XML declaration is prepended here: Blade cannot carry a literal
        // "<?xml" without the PHP compiler mistaking it for a PHP open tag.
        $xml = '<' . '?xml version="1.0" encoding="UTF-8"?' . ">\n"
            . view('app.recent-sets-feed', ['sets' => $sets, 'updated' => $updated])->render();

        return response($xml)
            ->header('Content-Type', 'application/atom+xml; charset=UTF-8');
    }

    /**
     * Fetch the newest sets as plain arrays (cache-safe), newest first.
     *
     * @return array<int, array<string, mixed>>
     */
    private function recentSets(): array
    {
        return Cache::remember(self::CACHE_KEY, self::CACHE_SECONDS, function () {
            $sets = tradingcardapi()->set()->list([
                'include' => 'genre,year',
                'order_by' => 'created_at',
                'sort' => 'desc',
                'limit' => 25,
            ]);

            $rows = [];
            foreach ($sets as $set) {
                $year = $set->year();
                $createdAt = $set->created_at ?? null;

                $rows[] = [
                    'id' => $set->id,
                    'name' => $set->name,
                    'year' => $year?->year ?? $year?->name ?? null,
                    'card_count' => $set->card_count ?? null,
                    'created_at' => $createdAt ? \Illuminate\Support\Carbon::parse($createdAt)->toAtomString() : null,
                    'url' => route('app.set', ['id' => $set->id, 'name' => str()->slug($set->name)]),
                ];
            }

            return $rows;
        });
    }
}
