<?php

use App\Console\Commands\SyncMatches;
use App\Console\Commands\ImportOpenFootballArchive;
use App\Console\Commands\SyncOpenLigaMatches;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(api: __DIR__.'/../routes/api.php', health: '/up')
    ->withCommands([SyncMatches::class, SyncOpenLigaMatches::class, ImportOpenFootballArchive::class])
    ->withSchedule(function (Illuminate\Console\Scheduling\Schedule $schedule): void {
        $schedule->command('matches:sync --date=today')->everyMinute()->withoutOverlapping(5);
        $schedule->command('matches:sync --date=tomorrow')->hourly()->withoutOverlapping(15);
        $schedule->command('matches:sync-openliga --date=today')->everyTenMinutes()->withoutOverlapping(10);
        $schedule->command('matches:sync-openliga --date=tomorrow')->hourly()->withoutOverlapping(15);
    })
    ->withMiddleware(function (Middleware $middleware): void {
        // Public endpoints are additionally rate-limited at the route level.
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Default JSON behavior is used for API routes.
    })
    ->create();
