<?php

namespace App\Services\Providers;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

final class ApiFootballClient
{
    private const URL = 'https://v3.football.api-sports.io/';

    /** @param array<string, int|string> $query
     *  @return list<mixed>
     */
    public function get(string $endpoint, array $query): array
    {
        if (! in_array($endpoint, ['leagues', 'teams', 'fixtures'], true)) {
            throw new RuntimeException('API-Football endpoint not allowed.');
        }

        $key = trim((string) config('topgolik.api_football.key', ''));
        if (! config('topgolik.api_football.enabled', false) || $key === '') {
            throw new RuntimeException('API-Football integration is disabled or no API key is configured.');
        }

        $this->reserveQuota();

        // The API key is used exclusively by the server and never logged.
        // No automatic retries: each attempt may consume a free-plan request.
        $response = Http::withHeaders(['x-apisports-key' => $key])
            ->acceptJson()->timeout(12)->get(self::URL.$endpoint, $query);

        if (! $response->successful()) {
            throw new RuntimeException('API-Football is unavailable (HTTP '.$response->status().').');
        }
        $payload = $response->json();
        if (! is_array($payload)
            || ! isset($payload['response']) || ! is_array($payload['response'])
            || ! array_is_list($payload['response'])
            || ! isset($payload['errors']) || ! is_array($payload['errors'])
            || $payload['errors'] !== []) {
            throw new RuntimeException('API-Football rejected the request or changed its schema.');
        }
        if (isset($payload['paging']['total']) && (int) $payload['paging']['total'] > 1) {
            throw new RuntimeException('API-Football response is paginated; refusing to treat partial data as complete.');
        }
        return $payload['response'];
    }

    private function reserveQuota(): void
    {
        $now = now('UTC');
        $day = 'topgolik:api-football:day:'.$now->format('Ymd');
        $minute = 'topgolik:api-football:minute:'.$now->format('YmdHi');
        $dayLimit = max(1, min(90, (int) config('topgolik.api_football.daily_budget', 80)));
        $minuteLimit = max(1, min(8, (int) config('topgolik.api_football.minute_budget', 8)));

        Cache::lock('topgolik:api-football:quota-lock', 10)->block(5, function () use (
            $day, $minute, $dayLimit, $minuteLimit, $now
        ): void {
            $dayUsed = (int) Cache::get($day, 0);
            $minuteUsed = (int) Cache::get($minute, 0);
            if ($dayUsed >= $dayLimit || $minuteUsed >= $minuteLimit) {
                throw new RuntimeException('API-Football free-tier local request budget exhausted.');
            }

            // Use the shared Laravel cache (Redis on production) for atomic
            // multi-worker local budgeting, with room for manual dashboard usage.
            Cache::put($day, $dayUsed + 1, $now->copy()->endOfDay()->addSecond());
            Cache::put($minute, $minuteUsed + 1, $now->copy()->addMinutes(2));
        });
    }
}
