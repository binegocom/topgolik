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
