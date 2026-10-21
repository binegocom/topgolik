<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('provider_sync_runs', function (Blueprint $table): void {
            $table->id();
            $table->string('provider', 24);
            $table->string('league_external_id', 80);
            $table->date('target_date');
            $table->boolean('success');
            $table->unsignedInteger('duration_ms');
            $table->unsignedInteger('fetched')->nullable();
            $table->unsignedInteger('stored')->nullable();
            $table->string('error_class', 160)->nullable();
            $table->timestampTz('started_at');
            $table->timestampTz('finished_at');
            $table->index(['provider', 'league_external_id', 'success', 'finished_at'], 'provider_sync_recent_idx');
            $table->index('finished_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('provider_sync_runs');
    }
};
