<?php
use App\Http\Controllers\MatchController;
use App\Http\Controllers\TeamSearchController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->middleware('throttle:90,1')->group(function (): void {
    Route::get('/health', [MatchController::class, 'health']);
    Route::get('/leagues', [MatchController::class, 'leagues']);
    Route::get('/search/teams', [TeamSearchController::class, 'index']);
    Route::get('/teams/{team}/matches', [MatchController::class, 'teamMatches'])->whereNumber('team');
    Route::get('/matches', [MatchController::class, 'index']);
    Route::get('/matches/{match}', [MatchController::class, 'show'])->whereNumber('match');
});
