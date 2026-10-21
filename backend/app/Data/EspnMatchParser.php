<?php
namespace App\Data;

use DateTimeImmutable;
use Throwable;

/** Maps an undocumented ESPN response into a stable internal contract. */
final class EspnMatchParser
{
    /** @return list<array<string, mixed>> */
    public function parse(array $payload): array
    {
        $matches = [];
        foreach (($payload['events'] ?? []) as $event) {
            if (! is_array($event) || ! isset($event['id'], $event['date'])) {
                continue;
            }
            $competition = $event['competitions'][0] ?? null;
            if (! is_array($competition)) {
                continue;
            }
            $sides = [];
            foreach (($competition['competitors'] ?? []) as $competitor) {
                if (! is_array($competitor)) { continue; }
                $side = $competitor['homeAway'] ?? null;
                if (in_array($side, ['home', 'away'], true)) {
                    $team = $competitor['team'] ?? [];
                    if (! is_array($team) || ! isset($team['id'], $team['displayName'])) { continue; }
                    $raw = $competitor['score'] ?? null;
                    $score = is_array($raw) ? ($raw['value'] ?? null) : $raw;
                    $logos = $team['logos'] ?? [];
                    $logo = is_array($logos) ? ($logos[0]['href'] ?? null) : null;
                    if (! is_string($logo) || $logo === '') {
                        $logo = $team['logo'] ?? null;
                    }
                    $sides[$side] = [
                        'external_id' => (string) $team['id'],
                        'name' => (string) $team['displayName'],
                        'abbreviation' => isset($team['abbreviation']) ? (string) $team['abbreviation'] : null,
                        'logo_url' => is_string($logo) && str_starts_with($logo, 'https://') ? $logo : null,
                        'score' => is_numeric($score) && (int) $score >= 0 && (int) $score <= 999 ? (int) $score : null,
                    ];
                }
            }
            if (! isset($sides['home'], $sides['away'])) { continue; }
            try {
                $start = new DateTimeImmutable((string) $event['date']);
            } catch (Throwable) {
                continue;
            }
            $state = $event['status']['type']['state'] ?? null;
            $status = match ($state) {
                'pre' => 'scheduled', 'in' => 'live', 'post' => 'finished', default => 'unknown',
            };
            $matches[] = [
                'external_id' => (string) $event['id'],
                'starts_at' => $start->setTimezone(new \DateTimeZone('UTC'))->format('Y-m-d H:i:sP'),
                'status' => $status,
                'status_detail' => substr((string) ($event['status']['type']['shortDetail'] ?? ''), 0, 80),
                'home' => $sides['home'], 'away' => $sides['away'],
            ];
        }
        return $matches;
    }
}
