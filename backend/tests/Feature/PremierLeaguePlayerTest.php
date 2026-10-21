<?php
namespace Tests\Feature;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

final class PremierLeaguePlayerTest extends TestCase
{
    private function fixture(): array
    {
        return [
            'teams' => [
                ['id' => 1, 'name' => 'North United'],
                ['id' => 2, 'name' => 'South City'],
            ],
            'elements' => [
                [
                    'id' => 11, 'team' => 1, 'web_name' => 'Example Forward',
                    'minutes' => 900, 'goals_scored' => 7, 'assists' => 3,
                    'total_points' => 69, 'expected_goals' => '5.42',
                    'expected_assists' => '1.30', 'form' => '6.0',
                ],
                [
                    'id' => 12, 'team' => 2, 'web_name' => 'Other Player',
                    'minutes' => 400, 'goals_scored' => 0, 'assists' => 1,
                    'total_points' => 21, 'expected_goals' => '0.12',
                    'expected_assists' => '0.60', 'form' => '2.0',
                ],
            ],
        ];
    }

    protected function setUp(): void
    {
        parent::setUp();
        Cache::forget('topgolik:fpl:bootstrap:v1');
        config()->set('topgolik.fpl.enabled', true);
    }

    public function test_free_keyless_player_feed_is_cached_and_searchable(): void
    {
        Http::fake([
            'fantasy.premierleague.com/api/bootstrap-static/*' =>
                Http::response($this->fixture(), 200),
        ]);
        $this->getJson('/api/v1/players/premier-league?q=Forward')
            ->assertOk()
            ->assertJsonPath('source', 'fantasy_premier_league')
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.name', 'Example Forward')
            ->assertJsonPath('data.0.goals', 7)
            ->assertJsonPath('data.0.expected_goals', '5.42');

        $this->getJson('/api/v1/players/premier-league?q=South')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.club', 'South City');
        Http::assertSentCount(1);
    }

    public function test_invalid_input_and_disabled_provider_are_safe(): void
    {
        $this->getJson('/api/v1/players/premier-league?limit=100')->assertUnprocessable();
        config()->set('topgolik.fpl.enabled', false);
        $this->getJson('/api/v1/players/premier-league')->assertStatus(503);
    }

    public function test_malformed_upstream_payload_is_not_shown_as_real_players(): void
    {
        Http::fake([
            'fantasy.premierleague.com/api/bootstrap-static/*' =>
                Http::response(['error' => 'bad shape'], 200),
        ]);
        $this->getJson('/api/v1/players/premier-league')->assertStatus(503);
    }
}
