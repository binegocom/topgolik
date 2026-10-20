<?php
namespace App\Http\Controllers;

use App\Models\Team;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

final class TeamSearchController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'q' => ['sometimes', 'nullable', 'string', 'max:80'],
        ]);
        $term = trim((string) ($data['q'] ?? ''));

        if ($term !== '') {
            $escaped = str_replace(['!', '%', '_'], ['!!', '!%', '!_'], mb_strtolower($term));
            $teams = Team::query()
                ->whereRaw("LOWER(name) LIKE ? ESCAPE '!'", ['%'.$escaped.'%'])
                ->orderBy('name')
                ->orderBy('id')
                ->limit(40)
                ->get();

            return response()->json([
                'featured' => [],
                'results' => $teams->map(fn (Team $team) => $this->serialize($team)),
            ]);
        }

        $catalog = config('topgolik.featured_teams', []);
        $allAliases = [];
        foreach ($catalog as $entry) {
            foreach ($entry['aliases'] ?? [] as $alias) {
                $allAliases[] = $alias;
            }
        }

        $teams = Team::query()
            ->whereIn('name', array_values(array_unique($allAliases)))
            ->orderByRaw("CASE WHEN provider = 'espn' THEN 0 ELSE 1 END")
            ->orderBy('id')
            ->get();

        $featured = [];
        foreach ($catalog as $entry) {
            $aliases = $entry['aliases'];
            // Prefer the official display label when present; fall back to
            // alternate upstream spellings without inventing a team ID.
            $resolved = $teams->first(fn (Team $team) => $team->name === $entry['label'])
                ?? $teams->first(fn (Team $team) => in_array($team->name, $aliases, true));

            $featured[] = [
                'name' => $entry['label'],
                'team' => $resolved !== null ? $this->serialize($resolved) : null,
            ];
        }

        return response()->json(['featured' => $featured, 'results' => []]);
    }

    /** @return array{id:int,name:string,logo_url:?string,provider:string} */
    private function serialize(Team $team): array
    {
        return [
            'id' => $team->id,
            'name' => $team->name,
            'logo_url' => $team->logo_url,
            'provider' => $team->provider,
        ];
    }
}
