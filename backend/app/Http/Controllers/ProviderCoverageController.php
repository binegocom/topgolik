<?php
namespace App\Http\Controllers;

use App\Support\LeaguePriority;
use Illuminate\Http\JsonResponse;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;

final class ProviderCoverageController extends Controller
{
    /**
     * Snapshot of data already ingested to Topgolik, not a claim about
     * upstream availability or completeness. Cached to protect PostgreSQL.
     */
    public function index(): JsonResponse
    {
        $snapshot = Cache::remember(
            'topgolik:provider-coverage:v1',
            now()->addSeconds(60),
            static function (): array {
                $rows = DB::table('leagues')
                    ->leftJoin('football_matches as matches', 'matches.league_id', '=', 'leagues.id')
                    ->select([
                        'leagues.id', 'leagues.name', 'leagues.country',
                        'leagues.provider', 'leagues.external_id',
                        'leagues.synced_at',
                    ])
                    ->selectRaw('COUNT(matches.id) AS total_matches')
                    ->selectRaw("SUM(CASE WHEN matches.status = 'live' THEN 1 ELSE 0 END) AS live_matches")
                    ->selectRaw("SUM(CASE WHEN matches.status = 'finished' THEN 1 ELSE 0 END) AS finished_matches")
                    ->selectRaw("SUM(CASE WHEN matches.status = 'scheduled' THEN 1 ELSE 0 END) AS scheduled_matches")
                    ->selectRaw('MAX(matches.synced_at) AS last_match_sync')
                    ->groupBy(
                        'leagues.id', 'leagues.name', 'leagues.country',
                        'leagues.provider', 'leagues.external_id', 'leagues.synced_at',
                    )
                    ->orderByRaw(LeaguePriority::sqlOrder())
                    ->orderBy('leagues.name')
                    ->orderBy('leagues.id')
                    ->limit(501)
                    ->get();

                $truncated = $rows->count() > 500;
                return [
                    'generated_at' => now('UTC')->toIso8601String(),
                    'complete' => ! $truncated,
                    'source' => 'topgolik_stored_matches',
                    'data' => $rows->take(500)->map(static fn ($row) => [
                        'league_id' => (int) $row->id,
                        'league' => $row->name,
                        'country' => $row->country,
                        'provider' => $row->provider,
                        'provider_league_id' => $row->external_id,
                        'total_matches' => (int) $row->total_matches,
                        'live_matches' => (int) $row->live_matches,
                        'finished_matches' => (int) $row->finished_matches,
                        'scheduled_matches' => (int) $row->scheduled_matches,
                        'last_ingestion_at' => $row->synced_at,
                        'last_match_sync' => $row->last_match_sync,
                    ])->values()->all(),
                ];
            },
        );

        return response()->json($snapshot);
    }
}
