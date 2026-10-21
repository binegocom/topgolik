<?php
namespace App\Console\Commands;

use App\Data\EspnMatchParser;
use App\Services\MatchIngestor;
use App\Services\ProviderSyncRecorder;
use App\Services\Providers\OpenLigaDbScoreProvider;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

final class SyncOpenLigaMatches extends Command
{
    protected $signature = 'matches:sync-openliga {--date=today : today, tomorrow or YYYY-MM-DD}';
    protected $description = 'Collect OpenLigaDB current-matchday football results';

    public function handle(OpenLigaDbScoreProvider $provider, EspnMatchParser $parser, ProviderSyncRecorder $recorder): int
    {
        $option = (string) $this->option('date');
        $date = match ($option) {
            'today' => now('UTC')->toDateString(),
            'tomorrow' => now('UTC')->addDay()->toDateString(),
            default => $option,
        };
        $parsed = \DateTimeImmutable::createFromFormat('!Y-m-d', $date);
        if (! $parsed || $parsed->format('Y-m-d') !== $date) {
            $this->error('Invalid --date.');
            return self::FAILURE;
        }

        $leagues = config('topgolik.openligadb.leagues', []);
        if ($leagues === []) {
            $this->warn('OpenLigaDB ingestion disabled: configure TOPGOLIK_OPENLIGA_LEAGUES.');
            return self::SUCCESS;
        }

        $ingestor = new MatchIngestor($provider, $parser);
        $failures = 0;
        foreach ($leagues as $league) {
            try {
                $totals = $recorder->run('openligadb', $league, str_replace('-', '', $date),
                    fn (): array => $ingestor->ingest($league, str_replace('-', '', $date)));
                $this->line("{$league}: {$totals['stored']} stored / {$totals['fetched']} returned");
            } catch (\Throwable $exception) {
                $failures++;
                Log::warning('OpenLigaDB ingestion failed', [
                    'league' => $league,
                    'date' => $date,
                    'exception' => $exception::class,
                ]);
                $this->warn("{$league}: unavailable or malformed upstream data");
            }
        }
        return $failures === 0 ? self::SUCCESS : self::FAILURE;
    }
}
