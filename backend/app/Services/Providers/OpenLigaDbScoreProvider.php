<?php
namespace App\Services\Providers;

use App\Contracts\ScoreProvider;
use App\Data\OpenLigaDbNormalizer;
use Illuminate\Support\Facades\Http;
use RuntimeException;

final class OpenLigaDbScoreProvider implements ScoreProvider
{
    public function __construct(private readonly OpenLigaDbNormalizer $normalizer) {}

    public function id(): string
    {
        return 'openligadb';
    }

    /** @return array<string, mixed> */
    public function scoreboard(string $league, string $date): array
    {
        $allowed = config('topgolik.openligadb.leagues', []);
        if (! in_array($league, $allowed, true) ||
            ! preg_match('/^[a-zA-Z0-9][a-zA-Z0-9._-]{1,35}$/D', $league)) {
            throw new RuntimeException('OpenLigaDB league is not configured.');
        }
        if (! preg_match('/^\d{8}$/D', $date) ||
            ! \DateTimeImmutable::createFromFormat('!Ymd', $date) ||
            \DateTimeImmutable::createFromFormat('!Ymd', $date)->format('Ymd') !== $date) {
            throw new RuntimeException('Invalid OpenLigaDB date.');
        }

        // Never allow an arbitrary host: the provider URL is fixed in code.
        $response = Http::acceptJson()
            ->timeout(12)
            ->retry(2, 500)
            ->get('https://api.openligadb.de/getmatchdata/'.rawurlencode($league));

        if (! $response->successful()) {
            throw new RuntimeException('OpenLigaDB unavailable (HTTP '.$response->status().').');
        }
        $rows = $response->json();
        if (! is_array($rows)) {
            throw new RuntimeException('OpenLigaDB response is not a JSON array.');
        }
        return $this->normalizer->normalize($rows, $league, $date);
    }
}
