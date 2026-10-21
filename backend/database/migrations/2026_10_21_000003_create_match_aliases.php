<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('match_aliases', function (Blueprint $table): void {
            $table->foreignId('alias_match_id')->primary()
                ->constrained('football_matches')->restrictOnDelete();
            $table->foreignId('canonical_match_id')
                ->constrained('football_matches')->restrictOnDelete();
            $table->timestampTz('created_at');
            $table->index('canonical_match_id');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('match_aliases');
    }
};
