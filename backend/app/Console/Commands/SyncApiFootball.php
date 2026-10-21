<?php

namespace App\Console\Commands;

use App\Data\EspnMatchParser;
use App\Services\ApiFootballCatalog;
use App\Services\MatchIngestor;
use App\Services\ProviderSyncRecorder;
use App\Services\Providers\ApiFootballClient;
use App\Services\Providers\ApiFootballScoreProvider;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

final class SyncApiFootball extends Command
{
    protected $signature = 'api-football:sync
        {--country= : Country to discover, default configured country}
        {--season= : Season start year, default current UTC football season}
        {--max-leagues=10 : Maximum verified competitions to import, from 1 to 12}
        {--league= : Restrict import to one source-verified league ID}
        {--fixtures : Include real match fixtures for the specified day}
        {--date=today : Date for fixtures: today, tomorrow or YYYY-MM-DD}';

    protected $description = 'Safely import real football clubs, crests and optional fixtures with free-tier limits';

    public function handle(
        ApiFootballCatalog $catalog,
        ApiFootballClient $client,
        EspnMatchParser $parser,
        ProviderSyncRecorder $recorder,
    ): int {
        if (! config('topgolik.api_football.enabled', false)
            || trim((string) config('topgolik.api_football.key', '')) === '') {
            $this->warn('API-Football is not enabled or the server-side API key is missing. No requests made.');
            return self::SUCCESS;
        }

        $today = now('UTC');
        $year = $today->month >= 7 ? $today->year : $today->year - 1;
        $season = $this->option('season') === null ? $year : filter_var(
            $this->option('season'), FILTER_VALIDATE_INT
        );
        $limit = filter_var($this->option('max-leagues'), FILTER_VALIDATE_INT);
        $country = trim((string) ($this->option('country') ?: config('topgolik.api_football.country', 'Turkey')));
        $selectedId = $this->option('league');
        if ($selectedId !== null && (
            ! ctype_digit((string) $selectedId) || (int) $selectedId < 1
        )) {
            $this->error('Provide a positive numeric --league ID returned by discovery.');
            return self::FAILURE;
        }
        if ($season === false || $season < 2000 || $season > $today->year + 1
            || $limit === false || $limit < 1 || $limit > 12) {
            $this->error('Season or max-leagues is invalid; max-leagues must be 1..12.');
            return self::FAILURE;
        }
        $option = (string) $this->option('date');
        $date = match ($option) {
            'today' => $today->toDateString(),
            'tomorrow' => $today->copy()->addDay()->toDateString(),
            default => $option,
        };
        $parsed = \DateTimeImmutable::createFromFormat('!Y-m-d', $date);
        if (! $parsed || $parsed->format('Y-m-d') !== $date) {
            $this->error('Invalid fixture date.');
            return self::FAILURE;
        }

        // The free account also has a 10/min upstream ceiling.
        // Throttle this bulk CLI independently of the shared quota lock so
        // a normal 10-league import cannot exhaust the 8/min app safety cap.
        $previousCall = false;
        $pace = static function () use (&$previousCall): void {
            if ($previousCall) {
                sleep(8);
            }
            $previousCall = true;
        };

        try {
            $pace();
            $leagues = $catalog->discover($country, $season);
        } catch (\Throwable $error) {
            Log::warning('API-Football league discovery failed', ['exception' => $error::class]);
            $this->error('League discovery unavailable or free plan has exhausted its budget.');
            return self::FAILURE;
        }

        if ($selectedId !== null) {
            $leagues = array_values(array_filter(
                $leagues, static fn (array $item): bool => $item['league_id'] === (int) $selectedId,
            ));
            if ($leagues === []) {
                $this->error('Requested league is not verified for this country and season.');
                return self::FAILURE;
            }
        }

        usort($leagues, static function (array $a, array $b): int {
            $priority = static function (string $name): int {
                $name = mb_strtolower($name);
                return match (true) {
                    str_contains($name, 'süper lig'), str_contains($name, 'super lig') => 0,
                    str_contains($name, '1. lig') => 1,
                    str_contains($name, '2. lig') => 2,
                    str_contains($name, '3. lig') => 3,
                    default => 10,
                };
            };
            return ($priority($a['name']) <=> $priority($b['name']))
                ?: strcmp($a['name'], $b['name'])
                ?: ($a['league_id'] <=> $b['league_id']);
        });

        $total = count($leagues);
        $selected = array_slice($leagues, 0, $limit);
        $this->info("{$total} verified leagues found; importing ".count($selected)." (daily free budget limited).");
        if ($total > $limit) {
            $this->warn('Some leagues were not imported. Use --league=ID for specific discovered divisions.');
        }
        if ($selected === []) {
            $this->warn('No competitions available from the source for this country and season.');
            return self::FAILURE;
        }

        $provider = new ApiFootballScoreProvider($client, $catalog);
        $ingestor = new MatchIngestor($provider, $parser);
        $errors = 0;
        foreach ($selected as $league) {
            $id = $league['league_id'];
            $externalId = $id.':'.$season;

            try {
                $pace();
                $teams = $catalog->teams($id, $season);
                $this->line("{$league['name']} [{$id}]: {$teams['teams']} teams; {$teams['logos']} logos");
            } catch (\Throwable $error) {
                $errors++;
                Log::warning('API-Football team import failed', [
                    'league_id' => $id, 'exception' => $error::class,
                ]);
                $this->warn("{$id}: team catalog unavailable or budget exhausted");
            }

            if ($this->option('fixtures')) {
                try {
                    $pace();
                    $stats = $recorder->run(
                        'apifootball', $externalId, str_replace('-', '', $date),
                        fn (): array => $ingestor->ingest($externalId, str_replace('-', '', $date)),
                    );
                    $this->line("{$id}: {$stats['stored']} real fixtures stored");
                } catch (\Throwable $error) {
                    $errors++;
                    Log::warning('API-Football fixture sync failed', [
                        'league_id' => $id, 'exception' => $error::class,
                    ]);
                    $this->warn("{$id}: fixture feed unavailable or budget exhausted");
                }
            }
        }
        if ($errors) {
            $this->warn("{$errors} catalogs or match feeds were unavailable; successful records were retained.");
        }
        return $errors === 0 ? self::SUCCESS : self::FAILURE;
    }
}
