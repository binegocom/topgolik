<?php
namespace Tests\Feature;

use App\Models\FootballMatch;
use App\Models\League;
use App\Models\Team;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class LeagueStandingsTest extends TestCase
{
    use RefreshDatabase;

    private function league(): League
    {
        return League::create([
            'provider' => 'espn', 'external_id' => 'tur.1',
            'name' => 'Süper Lig', 'country' => 'Turkey',
        ]);
    }

    private function team(int $id, string $name): Team
    {
        return Team::create([
            'provider' => 'espn', 'external_id' => (string) $id, 'name' => $name,
        ]);
    }

    private function fixture(League $league, Team $home, Team $away, string $date, ?int $goalsHome, ?int $goalsAway, string $status = 'finished'): void
    {
        static $counter = 0;
        FootballMatch::create([
            'provider' => 'espn', 'external_id' => 'fixture-'.(++$counter),
            'league_id' => $league->id,
            'home_team_id' => $home->id, 'away_team_id' => $away->id,
            'starts_at' => $date, 'status' => $status,
            'home_score' => $goalsHome, 'away_score' => $goalsAway,
            'synced_at' => now(),
        ]);
    }

    public function test_table_is_computed_only_from_real_finished_results(): void
    {
        $league = $this->league();
        $a = $this->team(10, 'Anatolia');
        $b = $this->team(11, 'Bosphorus');
        $c = $this->team(12, 'Coastal');

        $this->fixture($league, $a, $b, '2026-08-12 18:00:00', 3, 1);
        $this->fixture($league, $b, $c, '2026-08-18 18:00:00', 0, 0);
        $this->fixture($league, $c, $a, '2026-08-23 18:00:00', 2, 1);
        $this->fixture($league, $a, $c, '2026-08-27 18:00:00', 5, 0, 'live');
        $this->fixture($league, $a, $b, '2025-08-27 18:00:00', 9, 0);
        $this->fixture($league, $b, $a, '2026-09-01 18:00:00', null, null);

        $this->getJson('/api/v1/leagues/'.$league->id.'/standings?season=2026')
            ->assertOk()
            ->assertJsonPath('matches_counted', 3)
            ->assertJsonPath('source', 'derived_from_stored_final_scores')
            ->assertJsonPath('official', false)
            ->assertJsonPath('complete', false)
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('data.0.team.name', 'Coastal')
            ->assertJsonPath('data.0.points', 4)
            ->assertJsonPath('data.0.goal_difference', 1)
            ->assertJsonPath('data.1.team.name', 'Anatolia')
            ->assertJsonPath('data.1.points', 3)
            ->assertJsonPath('data.2.team.name', 'Bosphorus')
            ->assertJsonPath('data.2.points', 1)
            ->assertJsonPath('data.0.position', 1);
    }

    public function test_calendar_year_competition_window_is_selectable(): void
    {
        $league = $this->league();
        $a = $this->team(1, 'One');
        $b = $this->team(2, 'Two');
        $this->fixture($league, $a, $b, '2026-02-10 19:00:00', 1, 0);
        $this->fixture($league, $a, $b, '2026-08-10 19:00:00', 3, 0);

        $this->getJson('/api/v1/leagues/'.$league->id.'/standings?season=2026&season_start_month=1')
            ->assertOk()->assertJsonPath('matches_counted', 2);

        $this->getJson('/api/v1/leagues/'.$league->id.'/standings?season=2026&season_start_month=7')
            ->assertOk()->assertJsonPath('matches_counted', 1);
    }

    public function test_missing_data_returns_empty_nonofficial_table_without_invented_teams(): void
    {
        $league = $this->league();
        $this->getJson('/api/v1/leagues/'.$league->id.'/standings?season=2026')
            ->assertOk()
            ->assertJsonPath('matches_counted', 0)
            ->assertJsonCount(0, 'data');
        $this->assertDatabaseCount('teams', 0);
    }

    public function test_parameters_and_nonexistent_league_are_rejected(): void
    {
        $league = $this->league();
        $this->getJson('/api/v1/leagues/'.$league->id.'/standings?season=1999')->assertUnprocessable();
        $this->getJson('/api/v1/leagues/'.$league->id.'/standings?season_start_month=13')->assertUnprocessable();
        $this->getJson('/api/v1/leagues/999999/standings?season=2026')->assertNotFound();
    }
}
