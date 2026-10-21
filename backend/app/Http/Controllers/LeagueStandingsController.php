<?php
namespace App\Http\Controllers;

use App\Models\FootballMatch;
use App\Models\League;
use App\Models\Team;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

final class LeagueStandingsController extends Controller
{
    public function index(Request $request, League $league): JsonResponse
    {
        $params = $request->validate([
            'season' => ['sometimes', 'integer', 'between:2000,'.now('UTC')->year],
            'season_start_month' => ['sometimes', 'integer', 'in:1,7'],
        ]);

        // The source does not yet supply canonical competition seasons.
        // Clients may choose calendar-year or July-to-June seasons explicitly.
        $month = (int) ($params['season_start_month'] ?? 7);
        $today = now('UTC');
        $year = (int) ($params['season'] ?? ($today->month < $month ? $today->year - 1 : $today->year));
        $start = CarbonImmutable::create($year, $month, 1, 0, 0, 0, 'UTC');
        $end = $start->addYear();

        // A hard ceiling avoids unbounded queries if a provider sends malformed data.
        $matches = FootballMatch::query()
            ->where('league_id', $league->id)
            ->where('status', 'finished')
            ->whereNotNull('home_score')
            ->whereNotNull('away_score')
            ->where('starts_at', '>=', $start)
            ->where('starts_at', '<', $end)
            ->orderBy('id')
            ->limit(2501)
            ->get(['id', 'home_team_id', 'away_team_id', 'home_score', 'away_score']);

        if ($matches->count() > 2500) {
            return response()->json(['message' => 'Too many stored results for this season.'], 503);
        }

        $teamIds = $matches->flatMap(fn (FootballMatch $match) => [
            $match->home_team_id, $match->away_team_id,
        ])->unique()->values()->all();
        $teams = Team::query()
            ->whereIn('id', $teamIds)
            ->get(['id', 'name', 'logo_url'])
            ->keyBy('id');

        $table = [];
        foreach ($matches as $match) {
            foreach ([
                ['id' => $match->home_team_id, 'scored' => $match->home_score, 'conceded' => $match->away_score],
                ['id' => $match->away_team_id, 'scored' => $match->away_score, 'conceded' => $match->home_score],
            ] as $side) {
                $id = (int) $side['id'];
                if (! $teams->has($id)) {
                    continue;
                }
                $scored = (int) $side['scored'];
                $conceded = (int) $side['conceded'];
                if ($scored > 999 || $conceded > 999) {
                    continue;
                }

                $table[$id] ??= [
                    'team' => [
                        'id' => $id,
                        'name' => $teams[$id]->name,
                        'logo_url' => $teams[$id]->logo_url,
                    ],
                    'played' => 0, 'won' => 0, 'drawn' => 0, 'lost' => 0,
                    'goals_for' => 0, 'goals_against' => 0, 'goal_difference' => 0,
                    'points' => 0,
                ];
                $table[$id]['played']++;
                $table[$id]['goals_for'] += $scored;
                $table[$id]['goals_against'] += $conceded;
                $table[$id]['goal_difference'] += $scored - $conceded;
                if ($scored > $conceded) {
                    $table[$id]['won']++;
                    $table[$id]['points'] += 3;
                } elseif ($scored === $conceded) {
                    $table[$id]['drawn']++;
                    $table[$id]['points']++;
                } else {
                    $table[$id]['lost']++;
                }
            }
        }

        $rows = array_values($table);
        usort($rows, static fn (array $a, array $b): int =>
            ($b['points'] <=> $a['points'])
            ?: ($b['goal_difference'] <=> $a['goal_difference'])
            ?: ($b['goals_for'] <=> $a['goals_for'])
            ?: strcmp($a['team']['name'], $b['team']['name'])
            ?: ($a['team']['id'] <=> $b['team']['id'])
        );
        foreach ($rows as $index => &$row) {
            $row['position'] = $index + 1;
        }
        unset($row);

        return response()->json([
            'league' => ['id' => $league->id, 'name' => $league->name, 'country' => $league->country],
            'season' => $year,
            'season_start_month' => $month,
            'matches_counted' => $matches->count(),
            'source' => 'derived_from_stored_final_scores',
            'official' => false,
            'complete' => false,
            'data' => $rows,
        ]);
    }
}
