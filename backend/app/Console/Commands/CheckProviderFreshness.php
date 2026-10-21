<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

final class CheckProviderFreshness extends Command
{
    protected $signature = 'matches:check-providers {--max-age-minutes=45 : Maximum age of a successful completed sync}';
    protected $description = 'Report delayed or failing configured football providers';

    public function handle(): int
    {
        $age = filter_var($this->option('max-age-minutes'), FILTER_VALIDATE_INT);
        if ($age === false || $age < 5 || $age > 1440) {
            $this->error('max-age-minutes must be an integer between 5 and 1440.');
            return self::FAILURE;
        }

        $configured = [
            'espn' => config('topgolik.espn.leagues', []),
            'openligadb' => config('topgolik.openligadb.leagues', []),
        ];
        $observed = DB::table('provider_sync_runs')
            ->where('success', true)
            // Tomorrow's successful prefetch must never hide today's failed scoreboard sync.
            ->where('target_date', now('UTC')->toDateString())
            ->select('provider', 'league_external_id')
            ->selectRaw('MAX(finished_at) AS last_ok')
            ->groupBy('provider', 'league_external_id')
            ->get()
            ->keyBy(static fn ($row) => $row->provider.'|'.$row->league_external_id);

        $failures = 0;
        foreach ($configured as $provider => $leagues) {
            foreach (array_unique($leagues) as $league) {
                $league = trim((string) $league);
                if ($league === '') {
                    continue;
                }
                $lastOk = $observed->get($provider.'|'.$league)?->last_ok;
                if ($lastOk !== null && now('UTC')->diffInMinutes(
                    \Carbon\CarbonImmutable::parse($lastOk, 'UTC'), false
                ) > -$age) {
                    continue;
                }

                $failures++;
                // TTL suppresses alert storms without suppressing failed CLI exit status.
                $key = 'topgolik:provider-alert:'.hash('sha256', $provider.'|'.$league);
                if (Cache::add($key, true, now()->addHour())) {
                    Log::warning('Football provider not fresh', [
                        'provider' => $provider,
                        'league' => $league,
                        'last_success_at' => $lastOk,
                        'threshold_minutes' => $age,
                    ]);
                }
                $this->warn($provider.'/'.$league.' missing recent successful sync');
            }
        }

        if ($failures > 0) {
            $this->error($failures.' provider league feeds require attention.');
            return self::FAILURE;
        }

        $this->info('All configured feeds have recent successful syncs.');
        return self::SUCCESS;
    }
}
