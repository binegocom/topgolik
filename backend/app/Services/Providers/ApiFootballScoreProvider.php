<?php

namespace App\Services\Providers;

use App\Contracts\ScoreProvider;
use App\Services\ApiFootballCatalog;
use DateTimeImmutable;
use DateTimeZone;
use RuntimeException;
use Throwable;

final class ApiFootballScoreProvider implements ScoreProvider
{
    public function __construct(
        private readonly ApiFootballClient $client,
        private readonly ApiFootballCatalog $catalog,
    ) {}

    public function id(): string { return 'apifootball'; }

    /** @return array<string,mixed> */
    public function scoreboard(string $league, string $date): array
    {
        if (! preg_match('/^([1-9]\d{0,8}):(\d{4})$/D', $league, $parts)
            || ! preg_match('/^\d{8}$/D', $date)) {
            throw new RuntimeException('Invalid API-Football league/season/date.');
        }
        $leagueId = (int) $parts[1];
        $season = (int) $parts[2];
        $confirmed = $this->catalog->confirmedLeague($leagueId, $season);
        $dt = DateTimeImmutable::createFromFormat('!Ymd', $date, new DateTimeZone('UTC'));
        if (! $dt || $dt->format('Ymd') !== $date) {
            throw new RuntimeException('Invalid API-Football date.');
        }
        $rows = $this->client->get('fixtures', [
            'league' => $leagueId,
            'season' => $season,
            'date' => $dt->format('Y-m-d'),
            'timezone' => 'UTC',
        ]);

        $events = [];
        foreach ($rows as $entry) {
            if (! is_array($entry)
                || ! is_array($entry['fixture'] ?? null)
                || ! is_array($entry['teams'] ?? null)) {
                continue;
            }
            $fixture = $entry['fixture'];
            $id = $fixture['id'] ?? null;
            $start = $fixture['date'] ?? null;
            $code = $fixture['status']['short'] ?? null;
            if (! is_int($id) || $id < 1 || ! is_string($start)
                || ! is_string($code)) {
                continue;
            }
            try {
                $kickoff = new DateTimeImmutable($start);
            } catch (Throwable) {
                continue;
            }
            if ($kickoff->setTimezone(new DateTimeZone('UTC'))->format('Ymd') !== $date) {
                continue;
            }

            $home = $this->team($entry['teams']['home'] ?? null, 'home');
            $away = $this->team($entry['teams']['away'] ?? null, 'away');
            if ($home === null || $away === null) {
                continue;
            }

            $state = match ($code) {
                'NS', 'TBD', 'PST', 'CANC', 'ABD', 'AWD', 'WO' => 'pre',
                '1H', 'HT', '2H', 'ET', 'BT', 'P', 'INT', 'SUSP', 'LIVE' => 'in',
                'FT', 'AET', 'PEN' => 'post',
                default => 'unknown',
            };
            if ($state === 'in' || $state === 'post') {
                $home['score'] = $this->score($entry['goals']['home'] ?? null);
                $away['score'] = $this->score($entry['goals']['away'] ?? null);
            }

            $events[] = [
                'id' => (string) $id,
                'date' => $kickoff->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d\TH:i:s\Z'),
                'status' => ['type' => [
                    'state' => $state,
                    'shortDetail' => mb_substr($code, 0, 20),
                ]],
                'competitions' => [[
                    'competitors' => [$home, $away],
                ]],
            ];
        }

        if ($rows !== [] && $events === []) {
            throw new RuntimeException('API-Football fixtures returned but none could be safely normalized.');
        }

        return [
            'leagues' => [[
                'name' => $confirmed->name,
                'country' => ['name' => $confirmed->country],
            ]],
            'events' => $events,
        ];
    }

    /** @return array<string,mixed>|null */
    private function team(mixed $raw, string $side): ?array
    {
        if (! is_array($raw) || ! is_int($raw['id'] ?? null)
            || $raw['id'] < 1 || ! is_string($raw['name'] ?? null)
            || trim($raw['name']) === '') {
            return null;
        }

        $logo = $this->catalog->secureImage($raw['logo'] ?? null);
        return [
            'homeAway' => $side,
            'team' => [
                'id' => (string) $raw['id'],
                'displayName' => mb_substr(trim($raw['name']), 0, 255),
                'logos' => $logo !== null ? [['href' => $logo]] : [],
            ],
            'score' => null,
        ];
    }

    private function score(mixed $value): ?int
    {
        return is_int($value) && $value >= 0 && $value <= 999 ? $value : null;
    }
}
