<?php
namespace Tests\Feature;

use App\Models\FootballMatch;
use App\Models\League;
use App\Models\Team;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class TeamSearchTest extends TestCase
{
    use RefreshDatabase;

    private const LABELS = [
        'AmedSpor',
        'Vanspor FK',
        'Mardin 1969 Spor',
        'Batman Petrol Spor',
        'Muş Spor Kulübü',
        '12 Bingölspor',
        'Galatasaray',
        'Fenerbahçe',
        'Beşiktaş',
    ];

    public function test_featured_team_labels_are_always_in_the_exact_required_order(): void
    {
        $result = $this->getJson('/api/v1/search/teams')->assertOk()
            ->assertJsonCount(9, 'featured')
            ->assertJsonCount(0, 'results');

        $this->assertSame(self::LABELS, array_column($result->json('featured'), 'name'));
        foreach ($result->json('featured') as $entry) {
            $this->assertNull($entry['team']);
        }
        $this->assertDatabaseCount('teams', 0);
    }

    public function test_featured_entries_resolve_only_existing_source_backed_teams(): void
    {
        $amed = Team::create([
            'provider' => 'espn', 'external_id' => 'am-1',
            'name' => 'Amedspor', 'logo_url' => 'https://example.test/amed.png',
        ]);
        $galatasaray = Team::create([
            'provider' => 'espn', 'external_id' => 'gs-1',
            'name' => 'Galatasaray',
        ]);

        $result = $this->getJson('/api/v1/search/teams')->assertOk();
        $this->assertSame(self::LABELS, array_column($result->json('featured'), 'name'));
        $result->assertJsonPath('featured.0.team.id', $amed->id)
            ->assertJsonPath('featured.0.team.name', 'Amedspor')
            ->assertJsonPath('featured.0.team.logo_url', 'https://example.test/amed.png')
            ->assertJsonPath('featured.6.team.id', $galatasaray->id)
            ->assertJsonPath('featured.1.team', null);
    }

    public function test_query_searches_only_real_teams_and_hides_featured_entries(): void
    {
        $target = Team::create([
            'provider' => 'espn', 'external_id' => 'gs-1', 'name' => 'Galatasaray',
        ]);
        Team::create([
            'provider' => 'espn', 'external_id' => 'fb-1', 'name' => 'Fenerbahçe',
        ]);
        $this->getJson('/api/v1/search/teams?q=galata')
            ->assertOk()
            ->assertJsonCount(0, 'featured')
            ->assertJsonCount(1, 'results')
            ->assertJsonPath('results.0.id', $target->id);
    }

    public function test_wildcard_search_is_escaped_and_input_has_a_length_limit(): void
    {
        Team::create([
            'provider' => 'espn', 'external_id' => 'gs-1', 'name' => 'Galatasaray',
        ]);

        $this->getJson('/api/v1/search/teams?q=%25')->assertOk()
            ->assertJsonCount(0, 'results');
        $this->getJson('/api/v1/search/teams?q=_')->assertOk()
            ->assertJsonCount(0, 'results');
        $this->getJson('/api/v1/search/teams?q='.str_repeat('a', 81))
            ->assertUnprocessable();
    }

    public function test_team_matches_are_scoped_to_the_selected_real_team(): void
    {
        $a = Team::create(['provider' => 'espn', 'external_id' => 'a', 'name' => 'Amedspor']);
        $b = Team::create(['provider' => 'espn', 'external_id' => 'b', 'name' => 'Vanspor FK']);
        $c = Team::create(['provider' => 'espn', 'external_id' => 'c', 'name' => 'Galatasaray']);
        $league = League::create([
            'provider' => 'espn', 'external_id' => 'tur.2', 'name' => '1. Lig',
        ]);
        foreach ([[$a, $b, 'first'], [$b, $c, 'other']] as [$home, $away, $matchId]) {
            FootballMatch::create([
                'provider' => 'espn', 'external_id' => $matchId,
                'league_id' => $league->id,
                'home_team_id' => $home->id, 'away_team_id' => $away->id,
                'status' => 'scheduled',
                'starts_at' => '2026-10-21 15:00:00',
                'synced_at' => now(),
            ]);
        }

        $this->getJson('/api/v1/teams/'.$a->id.'/matches')
            ->assertOk()
            ->assertJsonPath('meta.total', 1)
            ->assertJsonPath('data.0.home.name', 'Amedspor');

        $this->getJson('/api/v1/teams/99999/matches')->assertNotFound();
    }
}
