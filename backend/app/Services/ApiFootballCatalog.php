<?php

namespace App\Services;

use App\Models\League;
use App\Models\Team;
use App\Services\Providers\ApiFootballClient;
use Illuminate\Support\Facades\DB;
use RuntimeException;

final class ApiFootballCatalog
{
    public function __construct(private readonly ApiFootballClient $client) {}

    /** @return list<array{league_id:int,season:int,name:string,country:string}> */
    public function discover(string $country, int $season): array
    {
        if (! preg_match('/^[\pL\s-]{2,60}$/uD', $country)) {
            throw new RuntimeException('Invalid API-Football country.');
        }
        $this->validateSeason($season);

        $rows = $this->client->get('leagues', ['country' => $country, 'season' => $season]);
        $found = [];
        foreach ($rows as $item) {
            if (! is_array($item) || ! is_array($item['league'] ?? null)) {
                continue;
            }
            $league = $item['league'];
            $id = $league['id'] ?? null;
            $name = $league['name'] ?? null;
            $sourceCountry = $item['country']['name'] ?? null;
            if (! is_int($id) || $id < 1 || ! is_string($name)
                || trim($name) === '' || mb_strlen($name) > 255
                || ! is_string($sourceCountry) || trim($sourceCountry) === '') {
                continue;
            }
            // Never add a league for a season the source did not actually list.
            $seasons = $item['seasons'] ?? [];
            if (! is_array($seasons) || ! collect($seasons)->contains(
                static fn ($s) => is_array($s) && ($s['year'] ?? null) === $season
            )) {
                continue;
            }

            $found[$id] = [
                'league_id' => $id,
                'season' => $season,
                'name' => trim($name),
                'country' => trim($sourceCountry),
            ];
        }

        DB::transaction(function () use ($found): void {
            foreach ($found as $row) {
                League::updateOrCreate(
                    ['provider' => 'apifootball',
                     'external_id' => $row['league_id'].':'.$row['season']],
                    ['name' => $row['name'], 'country' => $row['country']],
                );
            }
        }, 3);

        return array_values($found);
    }

    /** @return array{teams:int,logos:int} */
    public function teams(int $leagueId, int $season): array
    {
        $league = $this->confirmedLeague($leagueId, $season);
        $rows = $this->client->get('teams', ['league' => $leagueId, 'season' => $season]);
        if ($rows === []) {
            throw new RuntimeException('No verified teams available for this competition/season.');
        }
        $clubs = [];
        foreach ($rows as $item) {
            if (! is_array($item) || ! is_array($item['team'] ?? null)) {
                continue;
            }
            $team = $item['team'];
            $id = $team['id'] ?? null;
            $name = $team['name'] ?? null;
            if (! is_int($id) || $id < 1 || ! is_string($name)
                || trim($name) === '' || mb_strlen($name) > 255) {
                continue;
            }
            $logo = $team['logo'] ?? null;
            $clubs[$id] = [
                'id' => $id,
                'name' => trim($name),
                'code' => is_string($team['code'] ?? null) ? mb_substr(trim($team['code']), 0, 20) : null,
                'logo' => $this->secureImage($logo),
            ];
        }

        if ($clubs === []) {
            throw new RuntimeException('API-Football team list lacks usable verified team identities.');
        }

        $logos = 0;
        DB::transaction(function () use ($clubs, &$logos): void {
            foreach ($clubs as $team) {
                $values = ['name' => $team['name']];
                if ($team['code'] !== null && $team['code'] !== '') {
                    $values['abbreviation'] = $team['code'];
                }
                if ($team['logo'] !== null) {
                    $values['logo_url'] = $team['logo'];
                    $logos++;
                }
                Team::updateOrCreate(
                    ['provider' => 'apifootball', 'external_id' => (string) $team['id']],
                    $values,
                );
            }
        }, 3);

        return ['teams' => count($clubs), 'logos' => $logos];
    }

    public function confirmedLeague(int $leagueId, int $season): League
    {
        $this->validateSeason($season);
        if ($leagueId < 1) {
            throw new RuntimeException('Invalid API-Football league ID.');
        }
        $league = League::query()
            ->where('provider', 'apifootball')
            ->where('external_id', $leagueId.':'.$season)
            ->first();
        if ($league === null) {
            throw new RuntimeException('League not verified for this season; run api-football:sync --discover first.');
        }
        return $league;
    }

    public function secureImage(mixed $value): ?string
    {
        if (! is_string($value) || strlen($value) > 2048) {
            return null;
        }
        $parts = parse_url($value);
        return is_array($parts) && ($parts['scheme'] ?? null) === 'https'
            && is_string($parts['host'] ?? null)
            && ! isset($parts['user']) && ! isset($parts['pass'])
            ? $value : null;
    }

    private function validateSeason(int $season): void
    {
        if ($season < 2000 || $season > now('UTC')->year + 1) {
            throw new RuntimeException('Invalid or unsupported season year.');
        }
    }
}
