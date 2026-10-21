<?php

namespace App\Http\Controllers;

use App\Models\FootballMatch;
use Illuminate\Http\JsonResponse;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use RuntimeException;

final class MatchCenterController extends Controller
{
    public function show(FootballMatch $match): JsonResponse
    {
        $match->loadMissing(['league', 'homeTeam', 'awayTeam']);

        if ($match->provider !== 'espn' || $match->league->provider !== 'espn') {
            return response()->json([
                'source' => $match->provider,
                'supported' => false,
                'statistics' => ['home' => [], 'away' => []],
                'lineups' => ['home' => [], 'away' => []],
                'events' => [],
            ]);
        }

        $league = $match->league->external_id;
        $event = $match->external_id;
        if (! preg_match('/^[a-z0-9][a-z0-9._-]{1,63}$/D', $league)
            || ! preg_match('/^[0-9]{1,24}$/D', $event)) {
            return response()->json(['message' => 'Invalid source event identifier.'], 422);
        }

        try {
            $ttl = $match->status === 'live' ? 45 : 3600;
            $payload = Cache::remember(
                'topgolik:espn:summary:v1:'.$league.':'.$event,
                now()->addSeconds($ttl),
                static function () use ($league, $event): array {
                    $response = Http::acceptJson()->timeout(12)->retry(1, 500)
                        ->get(
                            'https://site.api.espn.com/apis/site/v2/sports/soccer/'.$league.'/summary',
                            ['event' => $event],
                        );
                    if (! $response->successful()) {
                        throw new RuntimeException('Match summary source unavailable.');
                    }
                    $body = $response->json();
                    if (! is_array($body) || ! array_key_exists('boxscore', $body)
                        && ! array_key_exists('rosters', $body)
                        && ! array_key_exists('keyEvents', $body)) {
                        throw new RuntimeException('Unexpected match summary schema.');
                    }
                    return $body;
                },
            );
        } catch (\Throwable) {
            return response()->json(['message' => 'Detailed match data temporarily unavailable.'], 503);
        }

        return response()->json([
            'source' => 'espn',
            'supported' => true,
            'statistics' => $this->mappedStatistics($match, $payload['boxscore']['teams'] ?? []),
            'lineups' => $this->mappedLineups($match, $payload['rosters'] ?? []),
            'events' => $this->mappedEvents($payload['keyEvents'] ?? []),
        ]);
    }

    /** @return array{home:list<array{label:string,value:string}>,away:list<array{label:string,value:string}>} */
    private function mappedStatistics(FootballMatch $match, mixed $teams): array
    {
        $mapped = ['home' => [], 'away' => []];
        if (! is_array($teams)) {
            return $mapped;
        }
        foreach ($teams as $entry) {
            if (! is_array($entry)) {
                continue;
            }
            $side = $this->sideForTeam($match, $entry['team']['id'] ?? null);
            if ($side === null || ! is_array($entry['statistics'] ?? null)) {
                continue;
            }
            foreach (array_slice($entry['statistics'], 0, 48) as $stat) {
                if (! is_array($stat)
                    || ! is_string($stat['name'] ?? null)
                    || ! is_scalar($stat['displayValue'] ?? null)) {
                    continue;
                }
                $label = trim($stat['label'] ?? $stat['name']);
                $value = trim((string) $stat['displayValue']);
                if ($label === '' || $value === '') {
                    continue;
                }
                $mapped[$side][] = [
                    'label' => mb_substr($label, 0, 80),
                    'value' => mb_substr($value, 0, 50),
                ];
            }
        }
        return $mapped;
    }

    /** @return array{home:list<array<string,mixed>>,away:list<array<string,mixed>>} */
    private function mappedLineups(FootballMatch $match, mixed $teams): array
    {
        $mapped = ['home' => [], 'away' => []];
        if (! is_array($teams)) {
            return $mapped;
        }
        foreach ($teams as $entry) {
            if (! is_array($entry)) {
                continue;
            }
            $side = $this->sideForTeam($match, $entry['team']['id'] ?? null);
            if ($side === null || ! is_array($entry['roster'] ?? null)) {
                continue;
            }
            foreach (array_slice($entry['roster'], 0, 35) as $player) {
                if (! is_array($player)
                    || ! is_string($player['athlete']['displayName'] ?? null)) {
                    continue;
                }
                $name = trim($player['athlete']['displayName']);
                if ($name === '') {
                    continue;
                }
                $mapped[$side][] = [
                    'name' => mb_substr($name, 0, 100),
                    'position' => is_string($player['position']['abbreviation'] ?? null)
                        ? mb_substr($player['position']['abbreviation'], 0, 10) : null,
                    'starter' => is_bool($player['starter'] ?? null) ? $player['starter'] : null,
                ];
            }
        }
        return $mapped;
    }

    /** @return list<array{minute:?string,title:string,description:?string}> */
    private function mappedEvents(mixed $events): array
    {
        $mapped = [];
        if (! is_array($events)) {
            return $mapped;
        }
        foreach (array_slice($events, 0, 75) as $event) {
            if (! is_array($event)) {
                continue;
            }
            $title = $event['type']['text'] ?? $event['text'] ?? null;
            if (! is_string($title) || trim($title) === '') {
                continue;
            }
            $minute = $event['clock']['displayValue'] ?? null;
            $mapped[] = [
                'minute' => is_string($minute) ? mb_substr($minute, 0, 20) : null,
                'title' => mb_substr(trim($title), 0, 150),
                'description' => is_string($event['text'] ?? null)
                    ? mb_substr($event['text'], 0, 250) : null,
            ];
        }
        return $mapped;
    }

    private function sideForTeam(FootballMatch $match, mixed $sourceId): ?string
    {
        if (! is_string($sourceId) && ! is_int($sourceId)) {
            return null;
        }
        $id = (string) $sourceId;
        if ($id === $match->homeTeam->external_id) {
            return 'home';
        }
        if ($id === $match->awayTeam->external_id) {
            return 'away';
        }
        return null;
    }
}
