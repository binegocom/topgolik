<?php

namespace Tests\Feature;

use App\Models\FootballMatch;
use App\Models\League;
use App\Models\Team;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

final class MatchCenterTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Cache::flush();
    }

    private function match(string $provider = 'espn', string $event = '12345'): FootballMatch
    {
        $league = League::create([
            'provider' => $provider, 'external_id' => 'tur.1',
            'name' => 'Süper Lig', 'country' => 'Turkey',
        ]);
        $home = Team::create([
            'provider' => $provider, 'external_id' => '501', 'name' => 'Home Team',
        ]);
        $away = Team::create([
            'provider' => $provider, 'external_id' => '502', 'name' => 'Away Team',
        ]);
        return FootballMatch::create([
            'provider' => $provider, 'external_id' => $event,
            'league_id' => $league->id,
            'home_team_id' => $home->id, 'away_team_id' => $away->id,
            'starts_at' => '2026-10-21 16:00:00', 'status' => 'finished',
            'synced_at' => now(),
        ]);
    }

    private function response(): array
    {
        return [
            'boxscore' => [
                'teams' => [
                    ['team' => ['id' => '502'], 'statistics' => [
                        ['name' => 'possessionPct', 'label' => 'Possession', 'displayValue' => '43.0%'],
                    ]],
                    ['team' => ['id' => '501'], 'statistics' => [
                        ['name' => 'shotsOnTarget', 'label' => 'Shots on target', 'displayValue' => '8'],
                    ]],
                ],
            ],
            'rosters' => [
                ['team' => ['id' => '501'], 'roster' => [
                    ['athlete' => ['displayName' => 'Goalkeeper Actual'], 'position' => ['abbreviation' => 'GK'], 'starter' => true],
                ]],
            ],
            'keyEvents' => [
                ['clock' => ['displayValue' => "67'"], 'type' => ['text' => 'Goal'],
                    'text' => 'Goal by verified player'],
            ],
        ];
    }

    public function test_real_summary_fields_are_mapped_to_correct_provider_team_identity_and_cached(): void
    {
        $match = $this->match();
        Http::fake([
            'site.api.espn.com/apis/site/v2/sports/soccer/tur.1/summary*' =>
                Http::response($this->response()),
        ]);
        for ($i = 0; $i < 2; $i++) {
            $this->getJson('/api/v1/matches/'.$match->id.'/center')
                ->assertOk()
                ->assertJsonPath('supported', true)
                ->assertJsonPath('statistics.home.0.label', 'Shots on target')
                ->assertJsonPath('statistics.home.0.value', '8')
                ->assertJsonPath('statistics.away.0.value', '43.0%')
                ->assertJsonPath('lineups.home.0.name', 'Goalkeeper Actual')
                ->assertJsonPath('lineups.home.0.starter', true)
                ->assertJsonPath('events.0.title', 'Goal')
                ->assertJsonPath('events.0.minute', "67'");
        }
        Http::assertSentCount(1);
    }

    public function test_other_provider_has_honest_empty_state_without_fetching_espn(): void
    {
        Http::fake();
        $match = $this->match('openligadb', 'source-1');
        $this->getJson('/api/v1/matches/'.$match->id.'/center')
            ->assertOk()
            ->assertJsonPath('supported', false)
            ->assertJsonCount(0, 'events')
            ->assertJsonCount(0, 'statistics.home');
        Http::assertNothingSent();
    }

    public function test_invalid_event_id_is_rejected_before_network_access(): void
    {
        Http::fake();
        $match = $this->match('espn', 'bad$event');
        $this->getJson('/api/v1/matches/'.$match->id.'/center')->assertStatus(422);
        Http::assertNothingSent();
    }

    public function test_incompatible_upstream_summary_has_explicit_failure(): void
    {
        Http::fake([
            'site.api.espn.com/apis/site/v2/sports/soccer/tur.1/summary*' =>
                Http::response(['unrecognized' => true]),
        ]);
        $match = $this->match('espn', '555');
        $this->getJson('/api/v1/matches/'.$match->id.'/center')->assertStatus(503);
    }
}
