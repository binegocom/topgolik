<?php
namespace App\Http\Controllers;

use App\Models\FootballMatch;
use App\Models\League;
use App\Models\Team;
use App\Support\LeaguePriority;
use Carbon\CarbonImmutable;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\DB;

final class MatchController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $input = $request->validate([
            'date' => ['sometimes', 'date_format:Y-m-d'],
            'offset_minutes' => ['sometimes', 'integer', 'between:-840,840'],
            'league' => ['sometimes', 'integer', 'min:1'],
            'status' => ['sometimes', 'in:live,scheduled,finished'],
            'page' => ['sometimes', 'integer', 'min:1', 'max:10000'],
        ]);
        $offset = (int) ($input['offset_minutes'] ?? 0);
        $date = $input['date'] ?? CarbonImmutable::now()->addMinutes($offset)->toDateString();
        $start = CarbonImmutable::parse($date.' 00:00:00', 'UTC')->subMinutes($offset);
        $query = FootballMatch::query()
            ->join('leagues', 'football_matches.league_id', '=', 'leagues.id')
            ->select('football_matches.*')
            ->with(['league', 'homeTeam', 'awayTeam'])
            ->where('football_matches.starts_at', '>=', $start)
            ->where('football_matches.starts_at', '<', $start->addDay());
        if (isset($input['league'])) { $query->where('football_matches.league_id', $input['league']); }
        if (isset($input['status'])) { $query->where('football_matches.status', $input['status']); }
        // Apply league priority before pagination so Turkish fixtures are never pushed to a later page.
        $page = $query->orderByRaw(LeaguePriority::sqlOrder())
            ->orderBy('football_matches.starts_at')
            ->orderBy('football_matches.id')
            ->paginate(100);
        return response()->json([
            'data' => $page->getCollection()->map(fn (FootballMatch $match) => $this->serialize($match)),
            'meta' => ['current_page' => $page->currentPage(), 'last_page' => $page->lastPage(), 'total' => $page->total()],
        ]);
    }

    public function show(FootballMatch $match): JsonResponse
    {
        return response()->json(['data' => $this->serialize($match->load(['league', 'homeTeam', 'awayTeam']))]);
    }

    public function leagues(): JsonResponse
    {
        return response()->json(['data' => League::query()
            ->orderByRaw(LeaguePriority::sqlOrder())
            ->orderBy('name')
            ->orderBy('id')
            ->get(['id','name','country','provider','external_id','synced_at'])]);
    }


    public function teamMatches(Team $team): JsonResponse
    {
        $page = FootballMatch::query()
            ->with(['league', 'homeTeam', 'awayTeam'])
            ->where(function ($query) use ($team): void {
                $query->where('home_team_id', $team->id)
                    ->orWhere('away_team_id', $team->id);
            })
            ->orderByDesc('starts_at')
            ->orderByDesc('id')
            ->paginate(30);

        return response()->json([
            'data' => $page->getCollection()->map(fn (FootballMatch $match) => $this->serialize($match)),
            'meta' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function health(): JsonResponse
    {
        try {
            DB::select('SELECT 1');
            return response()->json(['status' => 'ok']);
        } catch (\Throwable) {
            return response()->json(['status' => 'unavailable'], 503);
        }
    }

    private function serialize(FootballMatch $match): array
    {
        return [
            'id' => $match->id,
            'league' => ['id' => $match->league->id, 'name' => $match->league->name, 'country' => $match->league->country],
            'home' => ['id' => $match->homeTeam->id, 'name' => $match->homeTeam->name, 'logo_url' => $match->homeTeam->logo_url, 'score' => $match->home_score],
            'away' => ['id' => $match->awayTeam->id, 'name' => $match->awayTeam->name, 'logo_url' => $match->awayTeam->logo_url, 'score' => $match->away_score],
            'starts_at' => $match->starts_at->toIso8601String(),
            'status' => $match->status,
            'status_detail' => $match->status_detail,
            'updated_at' => $match->synced_at->toIso8601String(),
            'source' => $match->provider,
        ];
    }
}
