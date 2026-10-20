<?php
namespace App\Console\Commands;

use App\Services\MatchIngestor;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Log;

final class SyncMatches extends Command
{
    protected $signature = 'matches:sync {--date=today : today, tomorrow or YYYY-MM-DD}';
    protected $description = 'Fetch enabled football leagues into PostgreSQL';

    public function handle(MatchIngestor $ingestor): int
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
        $leagues = config('topgolik.espn.leagues', []);
        if ($leagues === []) {
            $this->error('TOPGOLIK_ESPN_LEAGUES is empty.');
            return self::FAILURE;
        }
        $failures = 0;
        foreach ($leagues as $league) {
            try {
                $totals = $ingestor->ingest($league, str_replace('-', '', $date));
                $this->line("{$league}: {$totals['stored']} saved / {$totals['fetched']} returned");
            } catch (\Throwable $error) {
                $failures++;
                Log::error('Score ingest failed', ['league' => $league, 'date' => $date, 'exception' => $error::class]);
                $this->warn("{$league}: provider unavailable or invalid response");
            }
        }
        return $failures === 0 ? self::SUCCESS : self::FAILURE;
    }
}
