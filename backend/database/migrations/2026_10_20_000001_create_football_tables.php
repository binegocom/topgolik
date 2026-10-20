<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('leagues', function (Blueprint $table): void {
            $table->id();
            $table->string('provider', 24);
            $table->string('external_id', 80);
            $table->string('name');
            $table->string('country')->nullable();
            $table->timestampTz('synced_at')->nullable();
            $table->timestampsTz();
            $table->unique(['provider', 'external_id']);
        });
        Schema::create('teams', function (Blueprint $table): void {
            $table->id();
            $table->string('provider', 24);
            $table->string('external_id', 80);
            $table->string('name');
            $table->string('abbreviation', 20)->nullable();
            $table->text('logo_url')->nullable();
            $table->timestampsTz();
            $table->unique(['provider', 'external_id']);
        });
        Schema::create('football_matches', function (Blueprint $table): void {
            $table->id();
            $table->string('provider', 24);
            $table->string('external_id', 80);
            $table->foreignId('league_id')->constrained()->restrictOnDelete();
            $table->foreignId('home_team_id')->constrained('teams')->restrictOnDelete();
            $table->foreignId('away_team_id')->constrained('teams')->restrictOnDelete();
            $table->timestampTz('starts_at');
            $table->string('status', 12)->default('scheduled');
            $table->string('status_detail', 80)->nullable();
            $table->unsignedSmallInteger('home_score')->nullable();
            $table->unsignedSmallInteger('away_score')->nullable();
            $table->timestampTz('synced_at');
            $table->timestampsTz();
            $table->unique(['provider', 'external_id']);
            $table->index(['starts_at', 'status']);
            $table->index(['league_id', 'starts_at']);
        });
    }
    public function down(): void
    {
        Schema::dropIfExists('football_matches');
        Schema::dropIfExists('teams');
        Schema::dropIfExists('leagues');
    }
};
