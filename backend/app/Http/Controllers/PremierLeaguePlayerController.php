<?php
namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

final class PremierLeaguePlayerController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $input = $request->validate([
            'q' => ['sometimes', 'string', 'max:80'],
            'limit' => ['sometimes', 'integer', 'between:1,50'],
        ]);
        if (! config('topgolik.fpl.enabled')) {
            return response()->json(['message' => 'Player data source not enabled.'], 503);
        }
        try {
            $source = Cache::remember(
                'topgolik:fpl:bootstrap:v1',
                now()->addSeconds(max(300, (int) config('topgolik.fpl.ttl', 1800))),
                function (): array {
                    $result = Http::acceptJson()->timeout(15)->retry(2, 500)
                        ->get('https://fantasy.premierleague.com/api/bootstrap-static/');
                    if (! $result->successful()) {
                        throw new RuntimeException('FPL data source unavailable.');
                    }
                    $data = $result->json();
                    if (! is_array($data)
                        || ! isset($data['elements'], $data['teams'])
                        || ! is_array($data['elements']) || ! is_array($data['teams'])
                        || ! array_is_list($data['elements']) || ! array_is_list($data['teams'])) {
                        throw new RuntimeException('FPL source schema mismatch.');
                    }
                    return $data;
                },
            );
        } catch (\Throwable) {
            return response()->json(['message' => 'Player data is temporarily unavailable.'], 503);
        }

        $clubs = [];
        foreach ($source['teams'] as $team) {
            if (is_array($team)
                && is_int($team['id'] ?? null)
                && is_string($team['name'] ?? null)
                && trim($team['name']) !== '') {
                $clubs[$team['id']] = trim($team['name']);
            }
        }
        $query = mb_strtolower(trim($input['q'] ?? ''));
        $items = [];
        foreach ($source['elements'] as $row) {
            if (! is_array($row)
                || ! is_int($row['id'] ?? null)
                || ! is_int($row['team'] ?? null)
                || ! isset($clubs[$row['team']])
                || ! is_string($row['web_name'] ?? null)
                || trim($row['web_name']) === '') {
                continue;
            }
            $name = trim($row['web_name']);
            if ($query !== '' && ! str_contains(mb_strtolower($name), $query)
                && ! str_contains(mb_strtolower($clubs[$row['team']]), $query)) {
                continue;
            }

            $items[] = [
                'source_id' => $row['id'],
                'name' => $name,
                'club' => $clubs[$row['team']],
                'minutes' => $this->nonNegativeInt($row['minutes'] ?? null),
                'goals' => $this->nonNegativeInt($row['goals_scored'] ?? null),
                'assists' => $this->nonNegativeInt($row['assists'] ?? null),
                'points' => $this->nonNegativeInt($row['total_points'] ?? null),
                'form' => $this->numericString($row['form'] ?? null),
                'expected_goals' => $this->numericString($row['expected_goals'] ?? null),
                'expected_assists' => $this->numericString($row['expected_assists'] ?? null),
            ];
            if (count($items) >= (int) ($input['limit'] ?? 30)) {
                break;
            }
        }

        return response()->json([
            'source' => 'fantasy_premier_league',
            'competition' => 'Premier League',
            'data' => $items,
        ]);
    }

    private function nonNegativeInt(mixed $value): ?int
    {
        return is_int($value) && $value >= 0 ? $value : null;
    }

    private function numericString(mixed $value): ?string
    {
        return (is_string($value) || is_int($value) || is_float($value)) && is_numeric($value)
            ? (string) $value
            : null;
    }
}
