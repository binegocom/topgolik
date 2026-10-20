<?php
namespace Tests\Feature;

use App\Data\EspnMatchParser;
use App\Data\OpenLigaDbNormalizer;
use App\Services\MatchIngestor;
use App\Services\Providers\OpenLigaDbScoreProvider;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

final class OpenLigaDbSyncTest extends TestCase
{
    use RefreshDatabase;

    private function match(): array
    {
        return [
            'matchID' => 12345,
            'leagueName' => '1. Bundesliga 2026/2027',
            'matchDateTimeUTC' => '2026-10-21T17:30:00Z',
            'matchIsFinished' => true,
            'team1' => ['teamId' => 11, 'teamName' => 'Home United', 'shortName' => 'Home'],
            'team2' => ['teamId' => 12, 'teamName' => 'Away United', 'shortName' => 'Away'],
            'matchResults' => [
                ['resultTypeID' => 1, 'pointsTeam1' => 0, 'pointsTeam2' => 1],
                ['resultTypeID' => 2, 'pointsTeam1' => 2, 'pointsTeam2' => 1],
            ],
        ];
    }

    public function test_adapter_stores_verified_final_scores_without_duplicates(): void
    {
        config()->set('topgolik.openligadb.leagues', ['bl1']);
        Http::fake(['api.openligadb.de/*' => Http::response([$this->match()], 200)]);

        $provider = new OpenLigaDbScoreProvider(new OpenLigaDbNormalizer);
        $ingestor = new MatchIngestor($provider, new EspnMatchParser);
        $this->assertSame(['fetched' => 1, 'stored' => 1], $ingestor->ingest('bl1', '20261021'));
        $ingestor->ingest('bl1', '20261021');

        $this->assertDatabaseCount('football_matches', 1);
        $this->getJson('/api/v1/matches?date=2026-10-21')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.home.score', 2)
            ->assertJsonPath('data.0.away.score', 1)
            ->assertJsonPath('data.0.source', 'openligadb')
            ->assertJsonPath('data.0.status', 'finished');
        Http::assertSentCount(2);
    }

    public function test_not_finished_match_does_not_invent_live_status_or_score(): void
    {
        $match = $this->match();
        $match['matchIsFinished'] = false;
        $match['matchResults'] = [];
        $normalized = (new OpenLigaDbNormalizer)->normalize([$match], 'bl1', '20261021');
        $parsed = (new EspnMatchParser)->parse($normalized);
        $this->assertSame('scheduled', $parsed[0]['status']);
        $this->assertNull($parsed[0]['home']['score']);
        $this->assertNull($parsed[0]['away']['score']);
    }

    public function test_other_date_is_filtered_out_without_fake_events(): void
    {
        $normalized = (new OpenLigaDbNormalizer)->normalize([$this->match()], 'bl1', '20261022');
        $this->assertSame([], $normalized['events']);
    }

    public function test_unconfigured_league_is_rejected_without_network_access(): void
    {
        config()->set('topgolik.openligadb.leagues', ['bl1']);
        Http::fake();
        $this->expectException(\RuntimeException::class);
        (new OpenLigaDbScoreProvider(new OpenLigaDbNormalizer))->scoreboard('other', '20261021');
    }

    public function test_upstream_schema_mismatch_raises_error(): void
    {
        config()->set('topgolik.openligadb.leagues', ['bl1']);
        Http::fake(['api.openligadb.de/*' => Http::response(['error' => 'bad shape'], 200)]);
        $this->expectException(\RuntimeException::class);
        (new OpenLigaDbScoreProvider(new OpenLigaDbNormalizer))->scoreboard('bl1', '20261021');
    }
}
