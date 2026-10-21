<?php

namespace Tests\Feature;

use App\Contracts\ScoreProvider;
use App\Data\EspnMatchParser;
use App\Models\League;
use App\Models\Team;
use App\Services\MatchIngestor;
use App\Services\TeamCatalogSync;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Http;
use RuntimeException;
use Tests\TestCase;

final class TeamCatalogSyncTest extends TestCase
{
    use RefreshDatabase;

    private function espnPayload(): array
    {
        return [
            'sports' => [[
                'leagues' => [[
                    'name' => 'Turkish Super Lig',
                    'country' => ['name' => 'Turkey'],
                    'teams' => [
                        ['team' => [
                            'id' => '451', 'displayName' => 'Galatasaray',
                            'abbreviation' => 'GAL',
                            'logos' => [['href' => 'https://a.espncdn.com/i/teamlogos/soccer/500/451.png']],
                        ]],
                        ['team' => [
                            'id' => '123', 'displayName' => 'Fenerbahçe',
                            'abbreviation' => 'FEN',
                            'logos' => [],
                        ]],
                    ],
                ]],
            ]],
        ];
    }

    public function test_espn_team_catalog_creates_real_clubs_and_league_without_any_fixture(): void
    {
        config()->set('topgolik.espn.leagues', ['tur.1']);
        Http::fake(['site.api.espn.com/*' => Http::response($this->espnPayload())]);

        $result = (new TeamCatalogSync)->espn('tur.1');

        $this->assertSame(['teams' => 2, 'logos' => 1], $result);
        $this->assertDatabaseCount('teams', 2);
        $this->assertDatabaseCount('football_matches', 0);
        $this->assertDatabaseHas('leagues', [
            'provider' => 'espn', 'external_id' => 'tur.1',
            'name' => 'Turkish Super Lig', 'country' => 'Turkey',
        ]);
        $this->assertDatabaseHas('teams', [
            'provider' => 'espn', 'external_id' => '451',
            'logo_url' => 'https://a.espncdn.com/i/teamlogos/soccer/500/451.png',
        ]);
        $this->getJson('/api/v1/search/teams?q=Galata')
            ->assertOk()
            ->assertJsonCount(1, 'results')
            ->assertJsonPath('results.0.logo_url', 'https://a.espncdn.com/i/teamlogos/soccer/500/451.png');
        $this->getJson('/api/v1/search/teams')
            ->assertOk()
            ->assertJsonPath('featured.6.team.name', 'Galatasaray');
        Http::assertSentCount(1);
    }

    public function test_upstream_missing_crest_does_not_erase_saved_catalog_crest_or_abbreviation(): void
    {
        config()->set('topgolik.espn.leagues', ['tur.1']);
        $logo = 'https://a.espncdn.com/i/teamlogos/soccer/500/451.png';
        Team::create([
            'provider' => 'espn', 'external_id' => '451',
            'name' => 'Galatasaray', 'abbreviation' => 'GAL',
            'logo_url' => $logo,
        ]);

        $source = $this->espnPayload();
        $source['sports'][0]['leagues'][0]['teams'][0]['team']['logos'] = [];
        unset($source['sports'][0]['leagues'][0]['teams'][0]['team']['abbreviation']);
        Http::fake(['site.api.espn.com/*' => Http::response($source)]);
        (new TeamCatalogSync)->espn('tur.1');

        $this->assertDatabaseHas('teams', [
            'provider' => 'espn', 'external_id' => '451',
            'abbreviation' => 'GAL', 'logo_url' => $logo,
        ]);

        $provider = new class implements ScoreProvider {
            public function id(): string { return 'espn'; }
            public function scoreboard(string $league, string $date): array
            {
                return [
                    'leagues' => [['name' => 'Turkish Super Lig', 'country' => ['name' => 'Turkey']]],
                    'events' => [[
                        'id' => 'event-1', 'date' => '2026-10-21T19:00:00Z',
                        'status' => ['type' => ['state' => 'pre']],
                        'competitions' => [['competitors' => [
                            ['homeAway' => 'home', 'team' => [
                                'id' => '451', 'displayName' => 'Galatasaray',
                            ]],
                            ['homeAway' => 'away', 'team' => [
                                'id' => '123', 'displayName' => 'Fenerbahçe',
                            ]],
                        ]]],
                    ]],
                ];
            }
        };
        (new MatchIngestor($provider, new EspnMatchParser))->ingest('tur.1', '20261021');
        $this->assertDatabaseHas('teams', [
            'provider' => 'espn', 'external_id' => '451',
            'abbreviation' => 'GAL', 'logo_url' => $logo,
        ]);
    }

    public function test_openligadb_imports_real_teams_with_provider_scoped_identity_and_logo(): void
    {
        config()->set('topgolik.openligadb.leagues', ['bl2']);
        Http::fake(['api.openligadb.de/*' => Http::response([
            ['teamId' => 100, 'teamName' => 'Sample German FC',
                'shortName' => 'SGF', 'teamIconUrl' => 'https://example.org/sgf.png'],
            ['teamId' => 101, 'teamName' => 'Next German FC', 'teamIconUrl' => 'http://unsafe.invalid/logo.png'],
        ])]);
        $result = (new TeamCatalogSync)->openLiga('bl2', 2026);
        $this->assertSame(['teams' => 2, 'logos' => 1], $result);
        $this->assertDatabaseHas('teams', [
            'provider' => 'openligadb', 'external_id' => '100',
            'logo_url' => 'https://example.org/sgf.png',
        ]);
        $this->assertDatabaseHas('teams', [
            'provider' => 'openligadb', 'external_id' => '101', 'logo_url' => null,
        ]);
        $this->assertDatabaseCount('football_matches', 0);
    }

    public function test_unconfigured_competition_is_rejected_before_http(): void
    {
        config()->set('topgolik.espn.leagues', ['tur.1']);
        config()->set('topgolik.openligadb.leagues', ['bl2']);
        Http::fake();

        foreach ([
            fn () => (new TeamCatalogSync)->espn('tur.2'),
            fn () => (new TeamCatalogSync)->openLiga('bl1', 2026),
        ] as $request) {
            try {
                $request();
                $this->fail('Unconfigured provider was accepted.');
            } catch (RuntimeException) {
                $this->assertTrue(true);
            }
        }
        Http::assertNothingSent();
    }

    public function test_bad_upstream_team_catalog_fails_without_writing_fake_clubs(): void
    {
        config()->set('topgolik.espn.leagues', ['tur.1']);
        Http::fake(['site.api.espn.com/*' => Http::response(['sports' => []])]);
        $this->expectException(RuntimeException::class);
        (new TeamCatalogSync)->espn('tur.1');
    }

    public function test_known_team_provider_ids_remain_distinct_across_sources(): void
    {
        Team::create(['provider' => 'espn', 'external_id' => '100', 'name' => 'Not German FC']);
        config()->set('topgolik.openligadb.leagues', ['bl2']);
        Http::fake(['api.openligadb.de/*' => Http::response([
            ['teamId' => 100, 'teamName' => 'German FC'],
        ])]);
        (new TeamCatalogSync)->openLiga('bl2', 2026);
        $this->assertDatabaseCount('teams', 2);
    }
}
