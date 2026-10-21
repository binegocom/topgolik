<?php
namespace App\Data;

use DateTimeImmutable;
use DateTimeZone;
use RuntimeException;

/** Convert completed CC0 football.json results to the existing score contract. */
final class OpenFootballArchiveNormalizer
{
    /**
     * @param array<string, mixed> $payload
     * @param array{country:string,timezone:string} $competition
     * @return array<string, mixed>
     */
    public function normalize(array $payload, string $leagueId, array $competition): array
    {
        $matches = $payload['matches'] ?? null;
        if (! is_array($matches) || ! array_is_list($matches)) {
            throw new RuntimeException('OpenFootball matches must be a list.');
        }

        $timezone = new DateTimeZone($competition['timezone']);
        $events = [];
        foreach ($matches as $row) {
            if (! is_array($row)) {
                throw new RuntimeException('Malformed OpenFootball match.');
            }
            $home = $row['team1'] ?? null;
            $away = $row['team2'] ?? null;
            $date = $row['date'] ?? null;
            $time = $row['time'] ?? null;
            $fullTime = $row['score']['ft'] ?? null;
            if (! is_string($home) || ! is_string($away)
                || trim($home) === '' || trim($away) === ''
                || ! is_string($date) || ! preg_match('/^\d{4}-\d{2}-\d{2}$/D', $date)
                || ! is_string($time) || ! preg_match('/^\d{2}:\d{2}$/D', $time)
                || ! is_array($fullTime) || count($fullTime) !== 2) {
                // Incomplete historical rows are skipped rather than inventing
                // a kickoff timestamp or reporting an unverified final score.
                continue;
            }

            $kickoff = DateTimeImmutable::createFromFormat('!Y-m-d H:i', $date.' '.$time, $timezone);
            if (! $kickoff || $kickoff->format('Y-m-d H:i') !== $date.' '.$time) {
                continue;
            }
            if (! $this->scoreValid($fullTime[0]) || ! $this->scoreValid($fullTime[1])) {
                continue;
            }
            $homeName = trim($home);
            $awayName = trim($away);
            $eventIdentity = implode('|', [$leagueId, $date, $time, mb_strtolower($homeName), mb_strtolower($awayName)]);
            $events[] = [
                'id' => hash('sha256', $eventIdentity),
                'date' => $kickoff->setTimezone(new DateTimeZone('UTC'))->format('Y-m-d\TH:i:s\Z'),
                'status' => ['type' => ['state' => 'post', 'shortDetail' => 'FT']],
                'competitions' => [[
                    'competitors' => [
                        $this->team('home', $homeName, $fullTime[0]),
                        $this->team('away', $awayName, $fullTime[1]),
                    ],
                ]],
            ];
        }

        if ($matches !== [] && $events === []) {
            throw new RuntimeException('OpenFootball archive has no reliable completed records.');
        }

        return [
            'leagues' => [[
                'name' => trim((string) ($payload['name'] ?? $leagueId)),
                'country' => ['name' => $competition['country']],
            ]],
            'events' => $events,
        ];
    }

    private function scoreValid(mixed $score): bool
    {
        return is_int($score) && $score >= 0 && $score <= 999;
    }

    /** @return array<string, mixed> */
    private function team(string $side, string $name, int $score): array
    {
        return [
            'homeAway' => $side,
            'team' => [
                'id' => hash('sha256', mb_strtolower($name)),
                'displayName' => $name,
            ],
            'score' => (string) $score,
        ];
    }
}
