<?php
namespace App\Console\Commands;

use App\Data\EspnMatchParser;
use App\Services\MatchIngestor;
use App\Services\Providers\OpenFootballArchiveProvider;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

final class ImportOpenFootballArchive extends Command
{
    protected $signature = 'matches:import-openfootball
        {season : Completed season, e.g. 2024-25}
        {league : Allowlisted league, e.g. tr.1}';
    protected $description = 'Import CC0 OpenFootball completed season results (manual archival operation)';

    public function handle(OpenFootballArchiveProvider $provider, EspnMatchParser $parser): int
    {
        $id = $this->argument('season').'/'.$this->argument('league');
        try {
            $results = (new MatchIngestor($provider, $parser))->ingest($id, now('UTC')->format('Ymd'));
            $this->info($results['stored'].' verified completed historical matches imported.');
            return self::SUCCESS;
        } catch (\Throwable $error) {
            Log::warning('OpenFootball archive import failed', [
                'league' => $id,
                'exception' => $error::class,
            ]);
            $this->error('Import failed: archived feed missing, incomplete or invalid.');
            return self::FAILURE;
        }
    }
}
