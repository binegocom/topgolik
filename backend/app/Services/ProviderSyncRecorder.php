<?php

namespace App\Services;

use Carbon\CarbonImmutable;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

final class ProviderSyncRecorder
{
    /**
     * @param callable():array{fetched:int,stored:int} $ingest
     * @return array{fetched:int,stored:int}
     */
    public function run(string $provider, string $league, string $date, callable $ingest): array
    {
        $started = CarbonImmutable::now('UTC');
        $startNs = hrtime(true);
        $result = null;
        $error = null;

        try {
            return $result = $ingest();
        } catch (Throwable $exception) {
            $error = $exception;
            throw $exception;
        } finally {
            try {
                DB::table('provider_sync_runs')->insert([
                    'provider' => $provider,
                    'league_external_id' => $league,
                    'target_date' => CarbonImmutable::createFromFormat('!Ymd', $date, 'UTC')->format('Y-m-d'),
                    'success' => $error === null,
                    'duration_ms' => min(4294967295, (int) (max(0, hrtime(true) - $startNs) / 1000000)),
                    'fetched' => $result['fetched'] ?? null,
                    'stored' => $result['stored'] ?? null,
                    'error_class' => $error ? substr($error::class, 0, 160) : null,
                    'started_at' => $started,
                    'finished_at' => CarbonImmutable::now('UTC'),
                ]);
            } catch (Throwable $metricsError) {
                // Preserve the original upstream error, never log tokens/payloads.
                Log::error('Provider monitoring insert failed', [
                    'provider' => $provider,
                    'exception' => $metricsError::class,
                ]);
            }
        }
    }
}
