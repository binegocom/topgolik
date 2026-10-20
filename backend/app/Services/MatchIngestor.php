<?php
namespace App\Services;

use App\Contracts\ScoreProvider;
use App\Data\EspnMatchParser;
use App\Models\FootballMatch;
use App\Models\League;
use App\Models\Team;
use Illuminate\Support\Facades\DB;

final class MatchIngestor
{
    public function __construct(
        private readonly ScoreProvider $provider,
        private readonly EspnMatchParser $parser,
    ) {}

    /** @return array{fetched:int,stored:int} */
    public function ingest(string $leagueId, string $date): array
    {
        $payload = $this->provider->scoreboard($leagueId, $date);
        $matches = $this->parser->parse($payload);
        // Avoid discarding valid upstream payloads when a schema change prevents mapping.
        if (($payload['events'] ?? []) !== [] && $matches === []) {
            throw new \RuntimeException('No upstream events could be normalized.');
        }
        $leagueData = $payload['leagues'][0] ?? [];
        $name = is_array($leagueData) && ! empty($leagueData['name'])
            ? (string) $leagueData['name'] : $leagueId;
        $country = is_array($leagueData) && isset($leagueData['country']['name'])
            ? (string) $leagueData['country']['name'] : null;
        DB::transaction(function () use ($leagueId, $name, $country, $matches): void {
            $league = League::updateOrCreate(
                ['provider' => $this->provider->id(), 'external_id' => $leagueId],
                ['name' => $name, 'country' => $country, 'synced_at' => now()],
            );
            foreach ($matches as $match) {
                $home = $this->saveTeam($match['home']);
                $away = $this->saveTeam($match['away']);
                FootballMatch::updateOrCreate(
                    ['provider' => $this->provider->id(), 'external_id' => $match['external_id']],
                    [
                        'league_id' => $league->id,
                        'home_team_id' => $home->id,
                        'away_team_id' => $away->id,
                        'starts_at' => $match['starts_at'],
                        'status' => $match['status'],
                        'status_detail' => $match['status_detail'],
                        'home_score' => $match['home']['score'],
                        'away_score' => $match['away']['score'],
                        'synced_at' => now(),
                    ],
                );
            }
        }, 3);
        return ['fetched' => count($payload['events']), 'stored' => count($matches)];
    }

    private function saveTeam(array $team): Team
    {
        return Team::updateOrCreate(
            ['provider' => $this->provider->id(), 'external_id' => $team['external_id']],
            ['name' => $team['name'], 'abbreviation' => $team['abbreviation'], 'logo_url' => $team['logo_url']],
        );
    }
}
