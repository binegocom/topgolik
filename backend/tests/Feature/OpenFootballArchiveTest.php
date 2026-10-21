<?php
namespace Tests\Feature;

use App\Data\EspnMatchParser;
use App\Data\OpenFootballArchiveNormalizer;
use App\Services\MatchIngestor;
use App\Services\Providers\OpenFootballArchiveProvider;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

final class OpenFootballArchiveTest extends TestCase
{
    use RefreshDatabase;

    private function archive(): array
    {
        return [
            'name' => 'Turkish Süper Lig 2024/25',
            'matches' => [
                [
                    'date' => '2024-08-10', 'time' => '21:45',
                    'team1' => 'Home Athletic', 'team2' => 'Away Athletic',
                    'score' => ['ft' => [2, 1]],
                ],
                [
                    'date' => '2024-08-11',
                    'team1' => 'Missing Clock', 'team2' => 'Unknown',
                    'score' => ['ft' => [1, 0]],
                ],
            ],
        ];
    }

    public function test_archival_source_imports_only_verified_finished_match_with_explicit_kickoff(): void
    {
        Http::fake([
            'raw.githubusercontent.com/openfootball/football.json/*' =>
                Http::response($this->archive()),
        ]);
        $provider = new OpenFootballArchiveProvider(new OpenFootballArchiveNormalizer);
        $ingestor = new MatchIngestor($provider, new EspnMatchParser);

        $this->assertSame(['fetched' => 1, 'stored' => 1],
            $ingestor->ingest('2024-25/tr.1', '20241021'));
        $ingestor->ingest('2024-25/tr.1', '20241021');
        $this->assertDatabaseCount('football_matches', 1);

        $this->getJson('/api/v1/matches?date=2024-08-10')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.status', 'finished')
            ->assertJsonPath('data.0.source', 'openfootball')
            ->assertJsonPath('data.0.league.country', 'Turkey')
            ->assertJsonPath('data.0.home.score', 2);
    }

    public function test_only_allowlisted_completed_seasons_and_leagues_are_fetched(): void
    {
        Http::fake();
        $provider = new OpenFootballArchiveProvider(new OpenFootballArchiveNormalizer);
        foreach (['2026-27/tr.1', '2024-25/unknown.1', '../bad', '2024-99/tr.1'] as $invalid) {
            try {
                $provider->scoreboard($invalid, '20261021');
                $this->fail('Invalid archive accepted: '.$invalid);
            } catch (\RuntimeException $e) {
                $this->assertNotEmpty($e->getMessage());
            }
        }
        Http::assertNothingSent();
    }

    public function test_invalid_archive_fails_closed_without_creating_match(): void
    {
        Http::fake([
            'raw.githubusercontent.com/openfootball/football.json/*' =>
                Http::response(['name' => 'Source', 'matches' => [[
                    'date' => '2024-08-10', 'team1' => 'Home', 'team2' => 'Away',
                    'score' => ['ft' => [1, 0]],
                ]]]),
        ]);
        $this->expectException(\RuntimeException::class);
        (new MatchIngestor(
            new OpenFootballArchiveProvider(new OpenFootballArchiveNormalizer),
            new EspnMatchParser,
        ))->ingest('2024-25/tr.1', '20261021');
    }
}
