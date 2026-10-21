<?php
namespace App\Services\Providers;

use App\Contracts\ScoreProvider;
use App\Data\OpenFootballArchiveNormalizer;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Imports completed historical seasons of the CC0 football.json repository.
 * Never uses the archive as a live feed.
 */
final class OpenFootballArchiveProvider implements ScoreProvider
{
    public function __construct(private readonly OpenFootballArchiveNormalizer $normalizer) {}

    public function id(): string
    {
        return 'openfootball';
    }

    /** @return array<string, mixed> */
    public function scoreboard(string $league, string $date): array
    {
        if (! preg_match('/^(\d{4})-(\d{2})\/([a-z]{2,4}\.\d|uefa\.cl)$/D', $league, $parts)) {
            throw new RuntimeException('Invalid OpenFootball season or league.');
        }
        $startYear = (int) $parts[1];
        $endYear = $startYear + 1;
        if ($startYear < 1990
            || (int) $parts[2] !== $endYear % 100
            || $endYear > (int) now('UTC')->year
            || ($endYear === (int) now('UTC')->year && (int) now('UTC')->month < 7)) {
            throw new RuntimeException('Only completed archival seasons may be imported.');
        }
        $leagueId = $parts[3];
        $countries = config('topgolik.openfootball.leagues', []);
        if (! isset($countries[$leagueId]) || ! is_array($countries[$leagueId])) {
            throw new RuntimeException('OpenFootball competition is not allowlisted.');
        }

        // Ignore the standard interface's date filter: a single archive import
        // intentionally persists the season once rather than querying each day.
        $url = sprintf(
            'https://raw.githubusercontent.com/openfootball/football.json/master/%s/%s.json',
            substr($league, 0, 7),
            $leagueId,
        );
        $response = Http::acceptJson()->timeout(20)->retry(2, 500)->get($url);
        if (! $response->successful()) {
            throw new RuntimeException('OpenFootball archive unavailable (HTTP '.$response->status().').');
        }
        $payload = $response->json();
        if (! is_array($payload) || ! isset($payload['matches']) || ! is_array($payload['matches'])) {
            throw new RuntimeException('Invalid OpenFootball archive schema.');
        }

        return $this->normalizer->normalize($payload, $league, $countries[$leagueId]);
    }
}
