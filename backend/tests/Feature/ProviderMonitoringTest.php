<?php

namespace Tests\Feature;

use App\Services\ProviderSyncRecorder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Tests\TestCase;

final class ProviderMonitoringTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config()->set('topgolik.espn.leagues', ['tur.1']);
        config()->set('topgolik.openligadb.leagues', []);
    }

    public function test_successful_provider_attempt_is_recorded_and_monitor_is_healthy(): void
    {
        $actual = (new ProviderSyncRecorder)->run(
            'espn', 'tur.1', '20261021',
            static fn (): array => ['fetched' => 2, 'stored' => 2],
        );

        $this->assertSame(2, $actual['stored']);
        $this->assertDatabaseHas('provider_sync_runs', [
            'provider' => 'espn', 'league_external_id' => 'tur.1',
            'target_date' => '2026-10-21', 'success' => true,
            'fetched' => 2, 'stored' => 2,
        ]);
        $this->artisan('matches:check-providers')->assertExitCode(0);
    }

    public function test_upstream_failure_is_recorded_without_leaking_payloads(): void
    {
        try {
            (new ProviderSyncRecorder)->run(
                'espn', 'tur.1', '20261021',
                static fn (): array => throw new RuntimeException('Private upstream response'),
            );
            $this->fail('Expected upstream failure.');
        } catch (RuntimeException $exception) {
            $this->assertSame('Private upstream response', $exception->getMessage());
        }

        $this->assertDatabaseHas('provider_sync_runs', [
            'provider' => 'espn', 'league_external_id' => 'tur.1',
            'success' => false, 'error_class' => RuntimeException::class,
        ]);
        $this->assertSame(0, DB::table('provider_sync_runs')->whereNotNull('stored')->count());
        $this->artisan('matches:check-providers')->assertExitCode(1);
    }

    public function test_outdated_success_fails_freshness_check(): void
    {
        (new ProviderSyncRecorder)->run('espn', 'tur.1', '20261021',
            static fn (): array => ['fetched' => 0, 'stored' => 0]);
        DB::table('provider_sync_runs')->update([
            'started_at' => now('UTC')->subHours(2),
            'finished_at' => now('UTC')->subHours(2),
        ]);
        Cache::forget('topgolik:provider-alert:'.hash('sha256', 'espn|tur.1'));
        $this->artisan('matches:check-providers --max-age-minutes=45')->assertExitCode(1);
        $this->artisan('matches:check-providers --max-age-minutes=bogus')->assertExitCode(1);
    }

    public function test_tomorrow_prefetch_cannot_mask_missing_todays_results(): void
    {
        (new ProviderSyncRecorder)->run(
            'espn', 'tur.1', now('UTC')->addDay()->format('Ymd'),
            static fn (): array => ['fetched' => 1, 'stored' => 1],
        );
        $this->artisan('matches:check-providers')->assertExitCode(1);

        (new ProviderSyncRecorder)->run(
            'espn', 'tur.1', now('UTC')->format('Ymd'),
            static fn (): array => ['fetched' => 2, 'stored' => 2],
        );
        $this->artisan('matches:check-providers')->assertExitCode(0);
    }

    public function test_disabled_provider_does_not_trigger_false_alert(): void
    {
        config()->set('topgolik.espn.leagues', []);
        $this->artisan('matches:check-providers')->assertExitCode(0);
    }
}
