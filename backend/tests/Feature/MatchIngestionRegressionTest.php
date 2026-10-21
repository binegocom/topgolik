<?php
namespace Tests\Feature;

use App\Contracts\ScoreProvider;
use App\Data\EspnMatchParser;
use App\Services\MatchIngestor;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class MatchIngestionRegressionTest extends TestCase
{
    use RefreshDatabase;

    /** @return array<string, mixed> */
    private function payload(string $status, mixed $homeScore, mixed $awayScore): array
    {
        return [
            'leagues' => [['name' => 'Actual League', 'country' => ['name' => 'Turkey']]],
            'events' => [[
                'id' => 'm-100',
                'date' => '2026-10-21T18:00:00Z',
                'status' => ['type' => ['state' => $status, 'shortDetail' => '']],
                'competitions' => [[
                    'competitors' => [
                        ['homeAway' => 'home', 'score' => $homeScore,
                            'team' => ['id' => 'h-1', 'displayName' => 'Home Verified']],
                        ['homeAway' => 'away', 'score' => $awayScore,
                            'team' => ['id' => 'a-1', 'displayName' => 'Away Verified']],
                    ],
                ]],
            ]],
        ];
    }

    public function test_a_stale_snapshot_cannot_downgrade_a_finished_match(): void
    {
        $provider = new class implements ScoreProvider {
            public array $data = [];
            public function id(): string { return 'test-source'; }
            public function scoreboard(string $league, string $date): array { return $this->data; }
        };
        $service = new MatchIngestor($provider, new EspnMatchParser);
        $provider->data = $this->payload('post', '2', '1');
        $service->ingest('tur.1', '20261021');
        $provider->data = $this->payload('pre', null, null);
        $service->ingest('tur.1', '20261021');
        $provider->data = $this->payload('in', '0', '0');
        $service->ingest('tur.1', '20261021');

        $this->assertDatabaseCount('football_matches', 1);
        $this->assertDatabaseHas('football_matches', [
            'provider' => 'test-source', 'external_id' => 'm-100',
            'status' => 'finished', 'home_score' => 2, 'away_score' => 1,
        ]);
    }

    public function test_missing_interim_scores_do_not_erase_previous_confirmed_scores(): void
    {
        $provider = new class implements ScoreProvider {
            public array $data = [];
            public function id(): string { return 'test-source'; }
            public function scoreboard(string $league, string $date): array { return $this->data; }
        };
        $service = new MatchIngestor($provider, new EspnMatchParser);
        $provider->data = $this->payload('in', '1', '0');
        $service->ingest('tur.1', '20261021');
        $provider->data = $this->payload('in', null, null);
        $service->ingest('tur.1', '20261021');
        $this->assertDatabaseHas('football_matches', [
            'status' => 'live', 'home_score' => 1, 'away_score' => 0,
        ]);

        $provider->data = $this->payload('post', '2', '0');
        $service->ingest('tur.1', '20261021');
        $this->assertDatabaseHas('football_matches', [
            'status' => 'finished', 'home_score' => 2, 'away_score' => 0,
        ]);
    }

    public function test_actual_fulltime_correction_is_still_accepted(): void
    {
        $provider = new class implements ScoreProvider {
            public array $data = [];
            public function id(): string { return 'test-source'; }
            public function scoreboard(string $league, string $date): array { return $this->data; }
        };
        $service = new MatchIngestor($provider, new EspnMatchParser);
        $provider->data = $this->payload('post', '1', '1');
        $service->ingest('tur.1', '20261021');
        $provider->data = $this->payload('post', '2', '1');
        $service->ingest('tur.1', '20261021');
        $this->assertDatabaseHas('football_matches', [
            'status' => 'finished', 'home_score' => 2, 'away_score' => 1,
        ]);
    }
}
