<?php
namespace App\Services\Providers;

use App\Contracts\ScoreProvider;
use Illuminate\Support\Facades\Http;
use RuntimeException;

final class EspnScoreProvider implements ScoreProvider
{
    public function id(): string { return 'espn'; }

    public function scoreboard(string $league, string $date): array
    {
        if (! preg_match('/^[a-z0-9][a-z0-9._-]{1,63}$/D', $league)) {
            throw new RuntimeException('Invalid upstream league identifier.');
        }
        if (! preg_match('/^\d{8}$/D', $date)) {
            throw new RuntimeException('Invalid upstream date.');
        }
        $base = rtrim(config('topgolik.espn.base_url'), '/');
        $response = Http::acceptJson()
            ->timeout(max(3, min(30, config('topgolik.espn.timeout'))))
            ->retry(2, 500)
            ->get("{$base}/{$league}/scoreboard", ['dates' => $date, 'limit' => 250]);
        if (! $response->successful()) {
            throw new RuntimeException('Upstream scoreboard unavailable (HTTP '.$response->status().').');
        }
        $payload = $response->json();
        if (! is_array($payload) || ! isset($payload['events']) || ! is_array($payload['events'])) {
            throw new RuntimeException('Upstream scoreboard schema mismatch.');
        }
        return $payload;
    }
}
