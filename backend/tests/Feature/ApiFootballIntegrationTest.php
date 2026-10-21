<?php

namespace Tests\Feature;

use App\Data\EspnMatchParser;
use App\Services\ApiFootballCatalog;
use App\Services\MatchIngestor;
use App\Services\Providers\ApiFootballClient;
use App\Services\Providers\ApiFootballScoreProvider;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Tests\TestCase;

final class ApiFootballIntegrationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();
        config()->set('topgolik.api_football.enabled', true);
        config()->set('topgolik.api_football.key', 'fixture-test-only');
        config()->set('topgolik.api_football.daily_budget', 80);
        config()->set('topgolik.api_football.minute_budget', 8);
    }

    private function leagues(): array
    {
        return [
            'errors' => [], 'paging' => ['current' => 1, 'total' => 1],
            'response' => [[
                'league' => ['id' => 777, 'name' => '3. Lig - Group 1'],
                'country' => ['name' => 'Turkey'],
                'seasons' => [['year' => 2026, 'current' => true]],
            ]],
        ];
    }

    private function teams(): array
    {
        return [
            'errors' => [], 'response' => [
                ['team' => ['id' => 451, 'name' => 'Mardin 1969 Spor',
                    'code' => 'MAR', 'logo' => 'https://media.api-sports.io/football/teams/451.png']],
                ['team' => ['id' => 452, 'name' => 'Batman Petrolspor',
                    'logo' => 'https://media.api-sports.io/football/teams/452.png']],
            ],
        ];
    }

    private function fixture(string $status, int $id, ?int $home, ?int $away): array
    {
        return [
            'fixture' => [
                'id' => $id, 'date' => '2026-10-21T19:00:00+00:00',
                'status' => ['short' => $status],
            ],
            'teams' => [
                'home' => ['id' => 451, 'name' => 'Mardin 1969 Spor',
                    'logo' => 'https://media.api-sports.io/football/teams/451.png'],
                'away' => ['id' => 452, 'name' => 'Batman Petrolspor',
                    'logo' => 'https://media.api-sports.io/football/teams/452.png'],
            ],
            'goals' => ['home' => $home, 'away' => $away],
        ];
    }

    public function test_source_only_creates_verified_league_teams_logos_and_real_fixtures(): void
    {
        Http::fake([
            'v3.football.api-sports.io/leagues*' => Http::response($this->leagues()),
            'v3.football.api-sports.io/teams*' => Http::response($this->teams()),
            'v3.football.api-sports.io/fixtures*' => Http::response([
                'errors' => [], 'response' => [
                    $this->fixture('NS', 10001, null, null),
                    $this->fixture('1H', 10002, 1, 0),
                    $this->fixture('FT', 10003, 2, 1),
                ],
            ]),
        ]);

        $catalog = new ApiFootballCatalog(new ApiFootballClient);
        $discovered = $catalog->discover('Turkey', 2026);
        $this->assertSame('3. Lig - Group 1', $discovered[0]['name']);
        $this->assertDatabaseHas('leagues', [
            'provider' => 'apifootball', 'external_id' => '777:2026',
            'country' => 'Turkey',
        ]);
        $this->assertDatabaseCount('football_matches', 0);

        $this->assertSame(['teams' => 2, 'logos' => 2], $catalog->teams(777, 2026));
        $this->assertDatabaseHas('teams', [
            'provider' => 'apifootball', 'external_id' => '451',
            'logo_url' => 'https://media.api-sports.io/football/teams/451.png',
        ]);

        $provider = new ApiFootballScoreProvider(new ApiFootballClient, $catalog);
        $result = (new MatchIngestor($provider, new EspnMatchParser))
            ->ingest('777:2026', '20261021');
        $this->assertSame(['fetched' => 3, 'stored' => 3], $result);
        $this->assertDatabaseHas('football_matches', [
            'provider' => 'apifootball', 'external_id' => '10001',
            'status' => 'scheduled', 'home_score' => null,
        ]);
        $this->assertDatabaseHas('football_matches', [
            'provider' => 'apifootball', 'external_id' => '10002',
            'status' => 'live', 'home_score' => 1, 'away_score' => 0,
        ]);
        $this->assertDatabaseHas('football_matches', [
            'provider' => 'apifootball', 'external_id' => '10003',
            'status' => 'finished', 'home_score' => 2, 'away_score' => 1,
        ]);

        $this->getJson('/api/v1/search/teams?q=Mardin')
            ->assertOk()->assertJsonCount(1, 'results')
            ->assertJsonPath('results.0.name', 'Mardin 1969 Spor')
            ->assertJsonPath('results.0.logo_url',
                'https://media.api-sports.io/football/teams/451.png');

        Http::assertSentCount(3);
        Http::assertSent(fn ($request) =>
            $request->hasHeader('x-apisports-key', 'fixture-test-only')
            && ! str_contains($request->url(), 'fixture-test-only'));
    }

    public function test_missing_key_never_fetches_external_data(): void
    {
        config()->set('topgolik.api_football.enabled', false);
        Http::fake();
        $this->artisan('api-football:sync')->assertExitCode(0);
        $this->assertDatabaseCount('leagues', 0);
        Http::assertNothingSent();

        config()->set('topgolik.api_football.enabled', true);
        config()->set('topgolik.api_football.key', '');
        $this->artisan('api-football:sync')->assertExitCode(0);
        Http::assertNothingSent();
    }

    public function test_budget_blocks_extra_call_without_leaking_key(): void
    {
        config()->set('topgolik.api_football.daily_budget', 1);
        Http::fake(['v3.football.api-sports.io/leagues*' => Http::response($this->leagues())]);
        $client = new ApiFootballClient;
        $client->get('leagues', ['country' => 'Turkey', 'season' => 2026]);
        try {
            $client->get('leagues', ['country' => 'Turkey', 'season' => 2026]);
            $this->fail('Budget exceeded');
        } catch (RuntimeException $error) {
            $this->assertStringContainsString('budget', $error->getMessage());
        }
        Http::assertSentCount(1);
    }

    public function test_upstream_api_errors_and_partial_pages_fail_closed(): void
    {
        Http::fake(['v3.football.api-sports.io/*' => Http::sequence()
            ->push(['errors' => ['plan' => 'Upgrade needed'], 'response' => []])
            ->push(['errors' => [], 'response' => [['id' => 1]],
                'paging' => ['current' => 1, 'total' => 2]])]);
        $client = new ApiFootballClient;
        foreach ([1, 2] as $_) {
            try {
                $client->get('leagues', ['country' => 'Turkey']);
                $this->fail('Invalid data accepted.');
            } catch (RuntimeException $error) {
                $this->assertNotEmpty($error->getMessage());
            }
        }
        $this->assertDatabaseCount('leagues', 0);
    }

    public function test_unverified_season_and_league_are_never_fabricated(): void
    {
        $payload = $this->leagues();
        $payload['response'][0]['seasons'] = [['year' => 2025]];
        Http::fake(['v3.football.api-sports.io/leagues*' => Http::response($payload)]);
        $catalog = new ApiFootballCatalog(new ApiFootballClient);
        $this->assertSame([], $catalog->discover('Turkey', 2026));
        $this->assertDatabaseCount('leagues', 0);
        try {
            $catalog->teams(777, 2026);
            $this->fail('Unknown league must be refused before network call.');
        } catch (RuntimeException $error) {
            $this->assertStringContainsString('verified', $error->getMessage());
        }
        Http::assertSentCount(1);
    }

    public function test_no_games_does_not_imply_fake_scores_or_missing_badges(): void
    {
        Http::fake([
            'v3.football.api-sports.io/leagues*' => Http::response($this->leagues()),
            'v3.football.api-sports.io/teams*' => Http::response($this->teams()),
            'v3.football.api-sports.io/fixtures*' => Http::response([
                'errors' => [], 'response' => [],
            ]),
        ]);
        $catalog = new ApiFootballCatalog(new ApiFootballClient);
        $catalog->discover('Turkey', 2026);
        $catalog->teams(777, 2026);
        $provider = new ApiFootballScoreProvider(new ApiFootballClient, $catalog);
        (new MatchIngestor($provider, new EspnMatchParser))
            ->ingest('777:2026', '20261021');
        $this->assertDatabaseCount('football_matches', 0);
        $this->assertDatabaseHas('teams', [
            'external_id' => '451',
            'logo_url' => 'https://media.api-sports.io/football/teams/451.png',
        ]);
    }

    public function test_fixed_upstream_endpoints_only(): void
    {
        Http::fake();
        $client = new ApiFootballClient;
        foreach (['http://attacker.test', '../../fixtures', 'admin'] as $endpoint) {
            try {
                $client->get($endpoint, []);
                $this->fail('Unsafe endpoint should be refused.');
            } catch (RuntimeException $error) {
                $this->assertStringContainsString('not allowed', $error->getMessage());
            }
        }
        Http::assertNothingSent();
    }
}
