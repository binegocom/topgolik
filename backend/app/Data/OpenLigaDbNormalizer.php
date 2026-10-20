<?php
namespace App\Data;

use DateTimeImmutable;
use DateTimeZone;
use RuntimeException;
use Throwable;

/**
 * Translates OpenLigaDB matchday responses to the existing scoreboard contract.
 * OpenLigaDB has no reliable explicit in-play status; never invent one.
 */
final class OpenLigaDbNormalizer
{
    /** @param list<mixed> $rows
     *  @return array<string, mixed>
     */
    public function normalize(array $rows, string $league, string $date): array
    {
        if (! array_is_list($rows)) {
            throw new RuntimeException('OpenLigaDB matchday must be a list.');
        }

        $events = [];
        $leagueName = $league;
        foreach ($rows as $row) {
            if (! is_array($row)) {
                throw new RuntimeException('Invalid OpenLigaDB match item.');
            }
            if (isset($row['leagueName']) && is_string($row['leagueName']) && trim($row['leagueName']) !== '') {
                $leagueName = trim($row['leagueName']);
            }
            $rawStart = $row['matchDateTimeUTC'] ?? null;
            if (! is_string($rawStart) || ! preg_match('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/D', $rawStart)) {
                continue;
            }
            try {
                $start = new DateTimeImmutable($rawStart);
            } catch (Throwable) {
                continue;
            }
            if ($start->setTimezone(new DateTimeZone('UTC'))->format('Ymd') !== $date) {
                continue;
            }

            $home = $this->team($row['team1'] ?? null, 'home');
            $away = $this->team($row['team2'] ?? null, 'away');
            if (! is_numeric($row['matchID'] ?? null) || (int) $row['matchID'] <= 0 || $home === null || $away === null) {
                continue;
            }

            $result = $this->finalResult($row['matchResults'] ?? []);
            if ($result !== null) {
                $home['score'] = (string) $result['home'];
                $away['score'] = (string) $result['away'];
            }

            $finished = ($row['matchIsFinished'] ?? false) === true;
            $events[] = [
                'id' => (string) $row['matchID'],
                'date' => $start->format('Y-m-d\TH:i:s\Z'),
                'status' => ['type' => [
                    'state' => $finished ? 'post' : 'pre',
                    'shortDetail' => $finished ? 'FT' : '',
                ]],
                'competitions' => [[
                    'competitors' => [$home, $away],
                ]],
            ];
        }

        return [
            'leagues' => [['name' => $leagueName]],
            'events' => $events,
        ];
    }

    /** @return array<string, mixed>|null */
    private function team(mixed $value, string $side): ?array
    {
        if (! is_array($value)
            || ! is_numeric($value['teamId'] ?? null)
            || (int) $value['teamId'] <= 0
            || ! is_string($value['teamName'] ?? null)
            || trim($value['teamName']) === '') {
            return null;
        }
        $team = [
            'id' => (string) $value['teamId'],
            'displayName' => trim($value['teamName']),
        ];
        $abbr = $value['shortName'] ?? null;
        if (is_string($abbr) && $abbr !== '') {
            $team['abbreviation'] = mb_substr($abbr, 0, 20);
        }
        $icon = $value['teamIconUrl'] ?? null;
        if (is_string($icon) && str_starts_with($icon, 'https://')) {
            $team['logos'] = [['href' => $icon]];
        }
        return [
            'homeAway' => $side,
            'team' => $team,
            'score' => null,
        ];
    }

    /** @return array{home:int,away:int}|null */
    private function finalResult(mixed $results): ?array
    {
        if (! is_array($results)) {
            return null;
        }
        foreach ($results as $result) {
            if (! is_array($result) || (int) ($result['resultTypeID'] ?? 0) !== 2) {
                continue;
            }
            $home = $result['pointsTeam1'] ?? null;
            $away = $result['pointsTeam2'] ?? null;
            if (! is_numeric($home) || ! is_numeric($away)) {
                return null;
            }
            $home = (int) $home;
            $away = (int) $away;
            if ($home < 0 || $away < 0 || $home > 999 || $away > 999) {
                return null;
            }
            return ['home' => $home, 'away' => $away];
        }
        return null;
    }
}
