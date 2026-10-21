<?php
namespace Tests\Feature;

use App\Models\FootballMatch;
use App\Models\League;
use App\Models\Team;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

final class ProviderCoverageTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        Cache::forget('topgolik:provider-coverage:v1');
    }

    public function test_coverage_has_no_fabricated_teams_or_matches(): void
    {
        $this->getJson('/api/v1/coverage')->assertOk()
            ->assertJsonPath('source', 'topgolik_stored_matches')
            ->assertJsonPath('complete', true)
            ->assertJsonCount(0, 'data');
    }

    public function test_turkish_league_is_first_and_counts_only_stored_match_statuses(): void
    {
        $english = League::create([
            'provider' => 'espn', 'external_id' => 'eng.1', 'name' => 'Premier League', 'country' => 'England',
        ]);
        $turkish = League::create([
            'provider' => 'espn', 'external_id' => 'tur.1', 'name' => 'Süper Lig', 'country' => 'Turkey',
        ]);
        $h = Team::create(['provider' => 'espn', 'external_id' => 'h', 'name' => 'Home']);
        $a = Team::create(['provider' => 'espn', 'external_id' => 'a', 'name' => 'Away']);

        foreach ([
            [$english, 'e1', 'finished'],
            [$turkish, 't1', 'live'],
            [$turkish, 't2', 'scheduled'],
        ] as [$league, $eventId, $status]) {
            FootballMatch::create([
                'provider' => 'espn', 'external_id' => $eventId,
                'league_id' => $league->id, 'home_team_id' => $h->id,
                'away_team_id' => $a->id, 'status' => $status,
                'starts_at' => now(), 'synced_at' => now(),
            ]);
        }

        $this->getJson('/api/v1/coverage')->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('data.0.league', 'Süper Lig')
            ->assertJsonPath('data.0.provider', 'espn')
            ->assertJsonPath('data.0.total_matches', 2)
            ->assertJsonPath('data.0.live_matches', 1)
            ->assertJsonPath('data.0.scheduled_matches', 1)
            ->assertJsonPath('data.0.finished_matches', 0)
            ->assertJsonPath('data.1.league', 'Premier League')
            ->assertJsonPath('data.1.finished_matches', 1);
    }

    public function test_coverage_is_cached_to_prevent_repeated_full_database_aggregations(): void
    {
        $league = League::create([
            'provider' => 'espn', 'external_id' => 'tur.1', 'name' => 'Süper Lig',
        ]);
        $this->getJson('/api/v1/coverage')->assertOk()
            ->assertJsonPath('data.0.total_matches', 0);

        $league->forceFill(['name' => 'Changed Name'])->save();

        $this->getJson('/api/v1/coverage')->assertOk()
            ->assertJsonPath('data.0.league', 'Süper Lig');
    }
}
