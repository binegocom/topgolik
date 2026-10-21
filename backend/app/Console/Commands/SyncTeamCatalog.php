<?php

namespace App\Console\Commands;

use App\Services\TeamCatalogSync;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

final class SyncTeamCatalog extends Command
{
    protected $signature = 'teams:sync-catalog
        {--provider=all : all, espn or openligadb}
        {--season= : Starting year for OpenLigaDB football season}';
    protected $description = 'Import complete upstream team catalogs and existing official crests independently of matchdays';

    public function handle(TeamCatalogSync $sync): int
    {
        $provider = (string) $this->option('provider');
        if (! in_array($provider, ['all', 'espn', 'openligadb'], true)) {
            $this->error('Invalid provider option.');
            return self::FAILURE;
        }
        $season = $this->option('season');
        $currentSeason = now('UTC')->month >= 7 ? now('UTC')->year : now('UTC')->year - 1;
        if ($season !== null && (! preg_match('/^\d{4}$/D', (string) $season)
            || (int) $season < 2000 || (int) $season > now('UTC')->year + 1)) {
            $this->error('Invalid season year.');
            return self::FAILURE;
        }
        $year = $season === null ? $currentSeason : (int) $season;

        $failures = 0;
        $successes = 0;
        if (in_array($provider, ['all', 'espn'], true)) {
            foreach (config('topgolik.espn.leagues', []) as $league) {
                try {
                    $result = $sync->espn($league);
                    $successes++;
                    $this->info("ESPN {$league}: {$result['teams']} teams, {$result['logos']} logo URLs");
                } catch (\Throwable $error) {
                    $failures++;
                    Log::warning('ESPN team catalog failed', [
                        'league' => $league, 'exception' => $error::class,
                    ]);
                    $this->warn("ESPN {$league}: provider unavailable or unsupported league");
                }
            }
        }
        if (in_array($provider, ['all', 'openligadb'], true)) {
            foreach (config('topgolik.openligadb.leagues', []) as $league) {
                try {
                    $result = $sync->openLiga($league, $year);
                    $successes++;
                    $this->info("OpenLigaDB {$league}/{$year}: {$result['teams']} teams, {$result['logos']} logo URLs");
                } catch (\Throwable $error) {
                    $failures++;
                    Log::warning('OpenLigaDB team catalog failed', [
                        'league' => $league, 'exception' => $error::class,
                    ]);
                    $this->warn("OpenLigaDB {$league}/{$year}: provider unavailable or unsupported league");
                }
            }
        }

        if ($successes === 0) {
            $this->error('No verified team catalogs imported. Check league config and source connectivity.');
            return self::FAILURE;
        }
        if ($failures > 0) {
            $this->warn("Imported {$successes} catalogs; {$failures} were unavailable.");
            return self::FAILURE;
        }
        return self::SUCCESS;
    }
}
