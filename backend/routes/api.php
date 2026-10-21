<?php
use App\Http\Controllers\MatchController;
use App\Http\Controllers\MatchCenterController;
use App\Http\Controllers\LeagueStandingsController;
use App\Http\Controllers\PremierLeaguePlayerController;
use App\Http\Controllers\TeamSearchController;
use App\Http\Controllers\ProviderCoverageController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->middleware('throttle:90,1')->group(function (): void {
    Route::get('/health', [MatchController::class, 'health']);
    Route::get('/leagues', [MatchController::class, 'leagues']);
    Route::get('/coverage', [ProviderCoverageController::class, 'index']);
    Route::get('/leagues/{league}/standings', [LeagueStandingsController::class, 'index'])->whereNumber('league');
    Route::get('/players/premier-league', [PremierLeaguePlayerController::class, 'index']);
    Route::get('/search/teams', [TeamSearchController::class, 'index']);
    Route::get('/teams/{team}/matches', [MatchController::class, 'teamMatches'])->whereNumber('team');
    Route::get('/matches', [MatchController::class, 'index']);
    Route::get('/matches/{match}/center', [MatchCenterController::class, 'show'])->whereNumber('match');
    Route::get('/matches/{match}', [MatchController::class, 'show'])->whereNumber('match');
});
