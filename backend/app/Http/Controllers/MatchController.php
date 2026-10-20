<?php
namespace App\Http\Controllers;

use App\Models\FootballMatch;
use App\Models\League;
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
            ->with(['league', 'homeTeam', 'awayTeam'])
            ->where('starts_at', '>=', $start)
            ->where('starts_at', '<', $start->addDay());
        if (isset($input['league'])) { $query->where('league_id', $input['league']); }
        if (isset($input['status'])) { $query->where('status', $input['status']); }
        $page = $query->orderBy('starts_at')->orderBy('id')->paginate(100);
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
        return response()->json(['data' => League::query()->orderBy('name')->get(['id','name','country','provider','external_id','synced_at'])]);
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
