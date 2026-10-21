<?php

namespace App\Console\Commands;

use App\Models\FootballMatch;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use RuntimeException;

final class LinkVerifiedMatchAlias extends Command
{
    protected $signature = 'matches:link-verified
        {canonical : Trusted canonical match database ID}
        {alias : Duplicate match database ID from another provider}
        {--confirm : Persist this explicit, reviewed cross-source match identity}';
    protected $description = 'Link two source-verified identical fixtures without deleting original records';

    public function handle(): int
    {
        $canonicalId = filter_var($this->argument('canonical'), FILTER_VALIDATE_INT,
            ['options' => ['min_range' => 1]]);
        $aliasId = filter_var($this->argument('alias'), FILTER_VALIDATE_INT,
            ['options' => ['min_range' => 1]]);
        if (! $canonicalId || ! $aliasId || $canonicalId === $aliasId) {
            $this->error('Provide two distinct positive match IDs.');
            return self::FAILURE;
        }
        try {
            $result = DB::transaction(function () use ($canonicalId, $aliasId): string {
                $canonical = FootballMatch::query()->with(['league', 'homeTeam', 'awayTeam'])
                    ->lockForUpdate()->findOrFail($canonicalId);
                $alias = FootballMatch::query()->with(['league', 'homeTeam', 'awayTeam'])
                    ->lockForUpdate()->findOrFail($aliasId);

                if ($canonical->provider === $alias->provider) {
                    throw new RuntimeException('Linking two records from the same provider is not permitted.');
                }
                if (DB::table('match_aliases')->where('alias_match_id', $canonicalId)
                    ->orWhere('canonical_match_id', $aliasId)->exists()) {
                    throw new RuntimeException('Nested and cyclic alias chains are forbidden.');
                }
                $existing = DB::table('match_aliases')->where('alias_match_id', $aliasId)->first();
                if ($existing) {
                    if ((int) $existing->canonical_match_id === $canonicalId) {
                        return 'Already linked.';
                    }
                    throw new RuntimeException('Alias is linked to a different canonical match.');
                }

                $countryA = $this->normalized($canonical->league->country ?? '');
                $countryB = $this->normalized($alias->league->country ?? '');
                if ($countryA === '' || $countryB === '' || $countryA !== $countryB) {
                    throw new RuntimeException('Both league countries must be verified and identical.');
                }
                if ($this->normalized($canonical->homeTeam->name) !== $this->normalized($alias->homeTeam->name)
                    || $this->normalized($canonical->awayTeam->name) !== $this->normalized($alias->awayTeam->name)) {
                    throw new RuntimeException('Home and away team names must match exactly after whitespace and case normalization.');
                }
                if (abs($canonical->starts_at->getTimestamp() - $alias->starts_at->getTimestamp()) > 1800) {
                    throw new RuntimeException('Kickoff times must be within 30 minutes.');
                }
                if ($canonical->status === 'finished' && $alias->status === 'finished'
                    && ($canonical->home_score !== $alias->home_score
                        || $canonical->away_score !== $alias->away_score)) {
                    throw new RuntimeException('Disagreeing final scores require manual investigation.');
                }
                if (! $this->option('confirm')) {
                    return 'Verified candidate only. Re-run with --confirm to persist.';
                }

                DB::table('match_aliases')->insert([
                    'alias_match_id' => $aliasId,
                    'canonical_match_id' => $canonicalId,
                    'created_at' => now('UTC'),
                ]);
                return 'Alias link persisted.';
            }, 3);
            if ($this->option('confirm') && $result === 'Alias link persisted.') {
                Log::info('Operator linked verified duplicate football fixture', [
                    'canonical_id' => $canonicalId, 'alias_id' => $aliasId,
                ]);
            }
            $this->info($result);
            return self::SUCCESS;
        } catch (\Throwable $error) {
            $this->error('Identity verification failed: '.$error->getMessage());
            return self::FAILURE;
        }
    }

    private function normalized(string $text): string
    {
        return mb_strtolower(trim(preg_replace('/\s+/u', ' ', $text) ?? $text));
    }
}
