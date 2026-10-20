<?php
use App\Http\Controllers\MatchController;
use Illuminate\Support\Facades\Route;

Route::prefix('v1')->middleware('throttle:90,1')->group(function (): void {
    Route::get('/health', [MatchController::class, 'health']);
    Route::get('/leagues', [MatchController::class, 'leagues']);
    Route::get('/matches', [MatchController::class, 'index']);
    Route::get('/matches/{match}', [MatchController::class, 'show'])->whereNumber('match');
});
