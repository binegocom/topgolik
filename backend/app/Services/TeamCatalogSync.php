<?php

namespace App\Services;

use App\Models\League;
use App\Models\Team;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use RuntimeException;

/**
 * Discover actual provider teams even when they have no fixture today.
 * Provider-scoped IDs are never inferred from names.
 */
final class TeamCatalogSync
{
    /** @return array{teams:int,logos:int} */
    public function espn(string $leagueId): array
    {
        if (! in_array($leagueId, config('topgolik.espn.leagues', []), true)
            || ! preg_match('/^[a-z0-9][a-z0-9._-]{1,63}$/D', $leagueId)) {
            throw new RuntimeException('ESPN competition is not configured.');
        }

        $base = rtrim((string) config('topgolik.espn.base_url'), '/');
        $response = Http::acceptJson()->timeout(15)->retry(1, 600)
            ->get("{$base}/{$leagueId}/teams", ['limit' => 500]);

        if (! $response->successful()) {
            throw new RuntimeException('ESPN teams endpoint unavailable (HTTP '.$response->status().').');
        }

        $payload = $response->json();
        $leagues = [];
        foreach (($payload['sports'] ?? []) as $sport) {
            if (! is_array($sport)) {
                continue;
            }
            foreach (($sport['leagues'] ?? []) as $league) {
                if (is_array($league)) {
                    $leagues[] = $league;
                }
            }
        }
        // Some upstream versions place the teams collection directly at root.
        if ($leagues === [] && is_array($payload) && isset($payload['teams'])) {
            $leagues = [$payload];
        }
        if ($leagues === []) {
            throw new RuntimeException('ESPN teams catalogue schema mismatch.');
        }

        $entries = [];
        $name = null;
        $country = null;
        foreach ($leagues as $league) {
            if (is_string($league['name'] ?? null) && trim($league['name']) !== '') {
                $name ??= trim($league['name']);
            }
            if (is_string($league['country']['name'] ?? null)) {
                $country ??= trim($league['country']['name']);
            }
            foreach (($league['teams'] ?? []) as $item) {
                $team = $item['team'] ?? $item;
                if (! is_array($team) || ! isset($team['id'], $team['displayName'])
                    || ! is_scalar($team['id']) || ! is_string($team['displayName'])) {
                    continue;
                }
                $id = trim((string) $team['id']);
                $title = trim($team['displayName']);
                if ($id === '' || $title === '' || strlen($id) > 80 || mb_strlen($title) > 255) {
                    continue;
                }

                $entries[$id] = [
                    'id' => $id,
                    'name' => $title,
                    'abbreviation' => $team['abbreviation'] ?? null,
                    'logo' => $this->logo($team['logos'] ?? null, $team['logo'] ?? null),
                ];
            }
        }

        if ($entries === [] || $name === null) {
            throw new RuntimeException('ESPN team catalogue contains no usable competition data.');
        }

        return $this->persist('espn', $leagueId, $name, $country, array_values($entries));
    }

    /** @return array{teams:int,logos:int} */
    public function openLiga(string $leagueId, int $season): array
    {
        if (! in_array($leagueId, config('topgolik.openligadb.leagues', []), true)
            || ! preg_match('/^[a-zA-Z0-9][a-zA-Z0-9._-]{1,35}$/D', $leagueId)
            || $season < 2000 || $season > (int) now('UTC')->year + 1) {
            throw new RuntimeException('OpenLigaDB competition or season is not configured.');
        }
        $response = Http::acceptJson()->timeout(15)->retry(1, 600)
            ->get("https://api.openligadb.de/getavailableteams/{$leagueId}/{$season}");
        if (! $response->successful()) {
            throw new RuntimeException('OpenLigaDB teams unavailable (HTTP '.$response->status().').');
        }
        $rows = $response->json();
        if (! is_array($rows) || ! array_is_list($rows)) {
            throw new RuntimeException('OpenLigaDB catalogue schema mismatch.');
        }
        $entries = [];
        foreach ($rows as $team) {
            if (! is_array($team) || ! is_numeric($team['teamId'] ?? null)
                || (int) $team['teamId'] <= 0 || ! is_string($team['teamName'] ?? null)) {
                continue;
            }
            $id = (string) (int) $team['teamId'];
            $name = trim($team['teamName']);
            if ($name === '' || mb_strlen($name) > 255) {
                continue;
            }
            $entries[$id] = [
                'id' => $id,
                'name' => $name,
                'abbreviation' => $team['shortName'] ?? null,
                'logo' => $this->logo(null, $team['teamIconUrl'] ?? null),
            ];
        }
        if ($entries === []) {
            throw new RuntimeException('OpenLigaDB competition has no verified team records.');
        }

        // OpenLigaDB's list is a team catalog, not proof of season fixture coverage.
        return $this->persist('openligadb', $leagueId, $leagueId, 'Germany', array_values($entries));
    }

    /** @param list<array{id:string,name:string,abbreviation:mixed,logo:?string}> $teams
     *  @return array{teams:int,logos:int}
     */
    private function persist(string $provider, string $leagueId, string $name, ?string $country, array $teams): array
    {
        $logos = 0;
        DB::transaction(function () use ($provider, $leagueId, $name, $country, $teams, &$logos): void {
            $existingLeague = League::query()->where('provider', $provider)
                ->where('external_id', $leagueId)->first();
            League::updateOrCreate(
                ['provider' => $provider, 'external_id' => $leagueId],
                [
                    'name' => ($provider === 'openligadb' && $existingLeague !== null)
                        ? $existingLeague->name : $name,
                    'country' => $country ?: $existingLeague?->country,
                    // Catalog refresh is NOT evidence of a successful matchday sync.
                    // Do not mutate the scoreboard ingestion timestamp here.
                ],
            );

            foreach ($teams as $entry) {
                $attrs = ['name' => $entry['name']];
                if (is_string($entry['abbreviation']) && trim($entry['abbreviation']) !== '') {
                    $attrs['abbreviation'] = mb_substr(trim($entry['abbreviation']), 0, 20);
                }
                if ($entry['logo'] !== null) {
                    $attrs['logo_url'] = $entry['logo'];
                    $logos++;
                }
                // Omitted logo does not erase a previously verified one.
                Team::updateOrCreate(
                    ['provider' => $provider, 'external_id' => $entry['id']],
                    $attrs,
                );
            }
        }, 3);

        return ['teams' => count($teams), 'logos' => $logos];
    }

    private function logo(mixed $logos, mixed $fallback): ?string
    {
        $candidate = is_array($logos) ? ($logos[0]['href'] ?? null) : null;
        if (! is_string($candidate) || $candidate === '') {
            $candidate = $fallback;
        }
        if (! is_string($candidate) || strlen($candidate) > 2048) {
            return null;
        }
        $parts = parse_url($candidate);
        return is_array($parts) && ($parts['scheme'] ?? null) === 'https'
            && ! empty($parts['host']) && ! isset($parts['user']) && ! isset($parts['pass'])
            ? $candidate : null;
    }
}
