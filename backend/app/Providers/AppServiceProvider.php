<?php
namespace App\Providers;

use App\Contracts\ScoreProvider;
use App\Services\Providers\EspnScoreProvider;
use Illuminate\Support\ServiceProvider;

final class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->bind(ScoreProvider::class, EspnScoreProvider::class);
    }

    public function boot(): void {}
}
