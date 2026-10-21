<?php

namespace Tests\Feature;

use App\Models\FootballMatch;
use App\Models\League;
use App\Models\Team;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

final class MatchAliasTest extends TestCase
{
    use RefreshDatabase;

    private function fixture(string $provider, string $event, string $home = 'Amedspor', string $away = 'Vanspor FK', int $homeScore = 2): FootballMatch
    {
        $league = League::firstOrCreate(
            ['provider' => $provider, 'external_id' => 'tur.2'],
            ['name' => '1. Lig', 'country' => 'Turkey'],
        );
        $a = Team::firstOrCreate(
            ['provider' => $provider, 'external_id' => 'team-a'],
            ['name' => $home],
        );
        $b = Team::firstOrCreate(
            ['provider' => $provider, 'external_id' => 'team-b'],
            ['name' => $away],
        );
        return FootballMatch::create([
            'provider' => $provider, 'external_id' => $event,
            'league_id' => $league->id,
            'home_team_id' => $a->id, 'away_team_id' => $b->id,
            'starts_at' => '2026-10-21 18:00:00',
            'status' => 'finished',
            'home_score' => $homeScore, 'away_score' => 1,
            'synced_at' => now(),
        ]);
    }

    public function test_verified_duplicate_is_hidden_only_after_operator_confirmation(): void
    {
        $trusted = $this->fixture('espn', 'fixture-1');
        $alias = $this->fixture('openligadb', 'fixture-900');

        $this->getJson('/api/v1/matches?date=2026-10-21')->assertOk()->assertJsonPath('meta.total', 2);
        $this->artisan('matches:link-verified '.$trusted->id.' '.$alias->id)->assertExitCode(0);
        $this->assertDatabaseCount('match_aliases', 0);

        $this->artisan('matches:link-verified '.$trusted->id.' '.$alias->id.' --confirm')->assertExitCode(0);
        $this->assertDatabaseHas('match_aliases', [
            'canonical_match_id' => $trusted->id,
            'alias_match_id' => $alias->id,
        ]);
        $this->getJson('/api/v1/matches?date=2026-10-21')
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.id', $trusted->id);
        $this->getJson('/api/v1/matches/'.$alias->id)->assertOk()
            ->assertJsonPath('data.id', $alias->id);
        $this->getJson('/api/v1/teams/'.$alias->home_team_id.'/matches')
            ->assertOk()->assertJsonCount(0, 'data');
        $this->getJson('/api/v1/leagues/'.$alias->league_id.'/standings?season=2026')
            ->assertOk()->assertJsonPath('matches_counted', 0);

        $this->artisan('matches:link-verified '.$trusted->id.' '.$alias->id.' --confirm')->assertExitCode(0);
        $this->assertDatabaseCount('match_aliases', 1);
    }

    public function test_unverified_names_or_conflicting_final_score_are_rejected(): void
    {
        $trusted = $this->fixture('espn', 'fixture-1');
        $different = $this->fixture('openligadb', 'fixture-2', 'Another Team');
        $this->artisan('matches:link-verified '.$trusted->id.' '.$different->id.' --confirm')->assertExitCode(1);
        $this->assertDatabaseCount('match_aliases', 0);

        $other = $this->fixture('another', 'fixture-3', 'Amedspor', 'Vanspor FK', 3);
        $this->artisan('matches:link-verified '.$trusted->id.' '.$other->id.' --confirm')->assertExitCode(1);
        $this->assertDatabaseCount('match_aliases', 0);
    }

    public function test_link_cycles_are_rejected(): void
    {
        $primary = $this->fixture('espn', 'one');
        $secondary = $this->fixture('another', 'two');
        $third = $this->fixture('third', 'three');
        $this->artisan('matches:link-verified '.$primary->id.' '.$secondary->id.' --confirm')->assertExitCode(0);
        $this->artisan('matches:link-verified '.$secondary->id.' '.$third->id.' --confirm')->assertExitCode(1);
        $this->artisan('matches:link-verified '.$third->id.' '.$primary->id.' --confirm')->assertExitCode(1);
        $this->assertSame(1, DB::table('match_aliases')->count());
    }
}
