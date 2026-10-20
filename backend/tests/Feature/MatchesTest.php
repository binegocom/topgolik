<?php
namespace Tests\Feature;

use App\Contracts\ScoreProvider;
use App\Services\MatchIngestor;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class MatchesTest extends TestCase
{
    use RefreshDatabase;

    public function test_empty_scoreboard_returns_empty_matches(): void
    {
        $this->getJson('/api/v1/matches?date=2026-10-21')->assertOk()->assertJsonCount(0, 'data');
    }

    public function test_invalid_date_is_rejected(): void
    {
        $this->getJson('/api/v1/matches?date=2026-15-89')->assertUnprocessable();
    }

    public function test_provider_sync_is_idempotent_and_api_exposes_real_ingested_data(): void
    {
        $provider = new class implements ScoreProvider {
            public function id(): string { return 'testsource'; }
            public function scoreboard(string $league, string $date): array
            {
                return ['leagues' => [['name' => 'Test Competition']], 'events' => [[
                    'id' => 'e100', 'date' => '2026-10-21T18:00:00Z',
                    'status' => ['type' => ['state' => 'post', 'shortDetail' => 'FT']],
                    'competitions' => [['competitors' => [
                        ['homeAway' => 'home', 'score' => '3', 'team' => ['id' => 'h', 'displayName' => 'Home']],
                        ['homeAway' => 'away', 'score' => '1', 'team' => ['id' => 'a', 'displayName' => 'Away']],
                    ]]],
                ]]];
            }
        };
        $ingestor = new MatchIngestor($provider, new \App\Data\EspnMatchParser);
        $ingestor->ingest('test.1', '20261021');
        $ingestor->ingest('test.1', '20261021');
        $this->assertDatabaseCount('football_matches', 1);
        $this->getJson('/api/v1/matches?date=2026-10-21')->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.home.score', 3)
            ->assertJsonPath('data.0.status', 'finished');
    }
}
