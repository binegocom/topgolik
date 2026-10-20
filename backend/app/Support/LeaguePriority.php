<?php
namespace App\Support;

/**
 * Global display policy: Turkey first, with Süper Lig before other Turkish leagues.
 *
 * This SQL expression is intentionally shared by match pagination and the league
 * catalog. Country aliases cover the locale names returned by supported feeds;
 * ESPN's "tur.*" identifiers still work when upstream omits country metadata.
 */
final class LeaguePriority
{
    public static function sqlOrder(): string
    {
        return <<<'SQL'
CASE
    WHEN leagues.provider = 'espn' AND leagues.external_id = 'tur.1' THEN 0
    WHEN LOWER(TRIM(COALESCE(leagues.country, ''))) IN
        ('turkey', 'turkiye', 'türkiye', 'tr', 'turquie', 'turchia', 'türkei')
        OR (leagues.provider = 'espn' AND leagues.external_id LIKE 'tur.%')
    THEN 1
    ELSE 2
END
SQL;
    }
}
