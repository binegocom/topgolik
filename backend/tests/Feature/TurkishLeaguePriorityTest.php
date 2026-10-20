<?php
namespace Tests\Feature;

use App\Models\FootballMatch;
use App\Models\League;
use App\Models\Team;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class TurkishLeaguePriorityTest extends TestCase
{
    use RefreshDatabase;

    private function league(string $source, string $externalId, string $name, ?string $country): League
    {
        return League::create([
            'provider' => $source,
            'external_id' => $externalId,
            'name' => $name,
            'country' => $country,
            'synced_at' => now(),
        ]);
    }

    private function match(League $league, string $externalId, string $time, string $status = 'scheduled'): FootballMatch
    {
        // Values here are isolated test fixtures and never served as runtime data.
        $home = Team::firstOrCreate(
            ['provider' => 'fixture', 'external_id' => 'home'],
            ['name' => 'Home Fixture'],
        );
        $away = Team::firstOrCreate(
            ['provider' => 'fixture', 'external_id' => 'away'],
            ['name' => 'Away Fixture'],
        );

        return FootballMatch::create([
            'provider' => $league->provider,
            'external_id' => $externalId,
            'league_id' => $league->id,
            'home_team_id' => $home->id,
            'away_team_id' => $away->id,
            'starts_at' => $time,
            'status' => $status,
            'synced_at' => now(),
        ]);
    }

    public function test_turkish_matches_are_first_even_if_foreign_matches_start_earlier(): void
    {
        $foreign = $this->league('espn', 'eng.1', 'Premier League', 'England');
        $turkish = $this->league('espn', 'tur.1', 'Süper Lig', null);

        $this->match($foreign, 'foreign-1', '2026-10-21 10:00:00');
        $turkishMatch = $this->match($turkish, 'turkish-1', '2026-10-21 22:00:00');

        $this->getJson('/api/v1/matches?date=2026-10-21')
            ->assertOk()
            ->assertJsonPath('meta.total', 2)
            ->assertJsonPath('data.0.id', $turkishMatch->id)
            ->assertJsonPath('data.0.league.name', 'Süper Lig');
    }

    public function test_turkish_leagues_are_ordered_before_other_countries_on_leagues_endpoint(): void
    {
        $this->league('espn', 'eng.1', 'Premier League', 'England');
        $this->league('other-provider', 'division-1', '1. Lig', 'Turkey');
        $this->league('espn', 'tur.1', 'Süper Lig', null);
        $this->league('espn', 'ger.1', 'Bundesliga', 'Germany');

        $this->getJson('/api/v1/leagues')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Süper Lig')
            ->assertJsonPath('data.1.name', '1. Lig')
            ->assertJsonPath('data.2.name', 'Bundesliga')
            ->assertJsonPath('data.3.name', 'Premier League');
    }

    public function test_priority_applies_before_pagination_even_with_one_hundred_foreign_matches(): void
    {
        $foreign = $this->league('espn', 'eng.1', 'Premier League', 'England');
        $turkish = $this->league('espn', 'tur.1', 'Süper Lig', 'Türkiye');

        for ($i = 0; $i < 105; $i++) {
            $this->match($foreign, 'foreign-'.$i, '2026-10-21 10:00:00');
        }
        $turkishMatch = $this->match($turkish, 'turkish-important', '2026-10-21 23:00:00');

        $this->getJson('/api/v1/matches?date=2026-10-21&page=1')
            ->assertOk()
            ->assertJsonCount(100, 'data')
            ->assertJsonPath('meta.total', 106)
            ->assertJsonPath('data.0.id', $turkishMatch->id);

        $this->getJson('/api/v1/matches?date=2026-10-21&page=2')
            ->assertOk()
            ->assertJsonCount(6, 'data');
    }

    public function test_api_filters_and_local_day_boundaries_still_work(): void
    {
        $foreign = $this->league('espn', 'eng.1', 'Premier League', 'England');
        $turkish = $this->league('other-provider', 'division-1', '1. Lig', 'Türkiye');

        $this->match($foreign, 'foreign-live', '2026-10-21 18:00:00', 'live');
        $turkishMatch = $this->match($turkish, 'turkish-live', '2026-10-21 23:00:00', 'live');
        $this->match($turkish, 'turkish-next-day', '2026-10-22 12:00:00', 'live');

        $this->getJson('/api/v1/matches?date=2026-10-21&status=live&offset_minutes=120')
            ->assertOk()
            ->assertJsonPath('meta.total', 2)
            ->assertJsonPath('data.0.id', $turkishMatch->id);

        $this->getJson('/api/v1/matches?date=2026-10-21&status=live&league='.$foreign->id)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.league.id', $foreign->id);
    }

    public function test_non_turkish_leagues_keep_kickoff_order(): void
    {
        $foreign = $this->league('espn', 'ger.1', 'Bundesliga', 'Germany');
        $later = $this->match($foreign, 'later', '2026-10-21 21:00:00');
        $earlier = $this->match($foreign, 'earlier', '2026-10-21 18:00:00');

        $this->getJson('/api/v1/matches?date=2026-10-21')
            ->assertOk()
            ->assertJsonPath('data.0.id', $earlier->id)
            ->assertJsonPath('data.1.id', $later->id);
    }
}
