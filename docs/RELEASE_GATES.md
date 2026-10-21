# Release gates

This repository is NOT production-ready until the following are verified.

- [ ] Acquire or verify rights to re-distribute current match data, crests, news, and player imagery.
- [ ] Confirm coverage, rate limits, availability and provider change policy for the intended countries and leagues.
- [ ] Replace unbounded polling with monitored ingestion controls and provider SLAs where needed.
- [ ] CI backend + Android checks green; run iOS builds and App Store validation on macOS.
- [ ] Build and ship signed Android App Bundle and iOS IPA via protected signing secrets.
- [ ] Validate database backups, restore drill, queue health, clock skew and disaster recovery.
- [ ] Add production HTTPS, network policies, admin access controls, metrics, alerts and log redaction.
- [ ] Decide whether account sync, followed-team notifications, deep links, analytics and content moderation are required.
- [ ] Verify platform privacy labels, privacy policy, data processing agreements, and store review compliance.
- [ ] Run load tests and security tests against a staging deployment, with provider access disabled for synthetic workloads.

## Data principles

Never fabricate an event, score, club, logo, lineup or status in the running application. All match data has traceable provider keys and ingestion timestamps. External payloads must be validated, allow-listed and stored using stable identifiers. A source failure never clears successful data; stale results remain explicitly timestamped.

## Additional free data providers

OpenLigaDB (no key, user-contributed match results) is polled for configured leagues at most every ten minutes and keeps provider-scoped team/match IDs. Non-finished fixtures must not be shown as live unless a reliable upstream in-play marker becomes available. Results are read only from finished match records and the correct result type. Do not configure competitions already imported by ESPN without an explicit canonical deduplication strategy.

## Free football sources used in Topgolik

| Source | Runtime data | Scheduling | Provenance |
| --- | --- | --- | --- |
| ESPN undocumented JSON feed | Live/scheduled fixtures for configured competitions | Current existing cadence | Unofficial: availability and permission subject to provider |
| OpenLigaDB | Current matchday, German lower leagues | Every 10 minutes today, hourly tomorrow | Open submission platform, no key |
| OpenFootball/football.json | Completed archive season fixtures and full-time results | Manual import only | CC0/public-domain historical JSON |

Historical feed example:

    docker compose exec api php artisan matches:import-openfootball 2024-25 tr.1
    docker compose exec api php artisan matches:import-openfootball 2024-25 en.1

Importing the same source/season again is idempotent. The repository contains some seasons without kickoff times; those rows are intentionally excluded. Never convert a season archive into live scores. Tournament snapshots and team IDs remain scoped by provider, and cross-provider duplicates may exist for the same physical match.

Repositories surveyed by stars and activity: hudl/open-data, probberechts/soccerdata, openfootball/football.json, OpenLigaDB/OpenLigaDB-Samples, omkarcloud/flashscore-scraper, Ryzellx/football-live-api, apdmatos/sofascore-api. GitHub stars are not provider uptime or legal authorization. StatsBomb's open event data is a different model and does not belong in the scoreboard pipeline. Unofficial scraped FotMob/Flashscore/SofaScore sources are NOT production-enabled without verified coverage, reliability and data terms.

The completed-season source is only invoked explicitly; it does not provide real-time scores. Unsupported competitions should not silently show invented results.

### Premier League player data (FPL)

FPL's no-key public `bootstrap-static/` JSON is exposed through `GET /api/v1/players/premier-league?q=...&limit=30`. The backend caches a single verified payload for at least five minutes (default 30), validates upstream types, and returns only source-provided player/club/stat fields. No external API key or extra dependency. It covers **only the English Premier League** and is not a replacement for world-wide player stats. This undocumented endpoint has no uptime, unlimited-requests or commercial redistribution guarantee. Disable quickly with `TOPGOLIK_FPL_ENABLED=false` if rights or reliability are not established.

## Computed provisional league tables

`GET /api/v1/leagues/{league}/standings?season=2026&season_start_month=7` derives played, won, drawn, lost, goals, goal difference, and three-points-per-win standings from actual ingested **finished** results. The response always includes `official:false`, `complete:false`, and `matches_counted`. It is **not** a federation table: head-to-head rules, point deductions, postponed games and incomplete coverage are not inferred. The client clearly labels these as provisional. Season start is explicitly selectable (January or July), with July default; the correct boundary varies by competition. Query size is capped without destructive operations. It does not invent fixtures or players.

## Stored-data coverage snapshot

`GET /api/v1/coverage` reports actual ingested league/source counts (scheduled, live, finished), last match sync and last league ingest. Results are bounded to 500 leagues and cached for 60 seconds. The endpoint explicitly reports stored data only, **not** upstream coverage, freshness SLA or licensing status. No API keys, private identifiers or fake matches are returned. Operational alerting, provider probe jobs and dashboard authentication remain release gates tracked in GitHub Issue #16.

## Provider ingestion monitoring (code-level verification)

The additive `provider_sync_runs` migration captures per-provider/league success, failure class (not payload/secrets), finished time, latency, fetched and stored counts. Both scheduled ESPN and OpenLigaDB sync commands record attempts, including exceptions. A scheduled `matches:check-providers` command validates each enabled configured league every 15 minutes; it emits log warnings at most once an hour per failing feed and a failed exit code when the last successful ingest is missing or too old (45 minutes by default). To run manually:

```bash
php artisan migrate --force
php artisan matches:check-providers --max-age-minutes=45
```

Failure logs alone are **not** a delivered push/email alert: connect the configured log output to an operator notification system and validate delivery before production. The check detects sync freshness, not the provider's real-time match completeness. ESPN polling is every five minutes to reduce unnecessary unauthenticated calls; hourly tomorrow sync remains unchanged. DB migrations are additive; no live row deletions are executed.

## Explicit cross-provider duplicate suppression

Database match IDs always retain their source identity. The additive `match_aliases` table stores operator-approved source-to-canonical references. `matches:link-verified CANONICAL_ID DUPLICATE_ID` verifies matching league countries, exactly matching normalized team names, kickoff times (30-minute tolerance) and non-conflicting completed scores. The command **does not write** without `--confirm`. No fuzzy or speculative automatic merging is permitted. Once explicitly linked, duplicate aliases are suppressed from match list, team match list and calculated league standings; existing detail URLs remain readable for audit. Never edit or delete source matches as part of aliasing. New upstream identities and corrected kickoff times must be reviewed again before linking. Synonyms and different spelling require independent verified team mapping in a future revision.
