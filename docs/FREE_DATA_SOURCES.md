# Free football data sources — Topgolik

Audit date: 2026-10-21. Public source documentation and GitHub metadata were inspected. Stars do not equal uptime, reliability or legal right to redistribute data.

## Integrated provider feeds

| Source | Key required | Purpose | Limitations |
|---|---|---|---|
| ESPN site API | No | Live matchday soccer scoreboard | Undocumented, not unlimited, configured league list only |
| OpenLigaDB | No | Current matchday German leagues bl2 and bl3 by default | User-entered scores, no reliable explicit in-play status |
| OpenFootball football.json | No | Completed-season archive results | CC0 license; manually sourced match data can be stale; import complete past seasons only |
| Fantasy Premier League public bootstrap | No | Premier League player form/goals/assists/xG | England only; undocumented API, cache 30m; commercial redistribution not confirmed |

OpenFootball import example: php artisan matches:import-openfootball 2024-25 tr.1
OpenLigaDB scheduled command: php artisan matches:sync-openliga --date=today
FPL read-only API: GET /api/v1/players/premier-league?q=...&limit=30
Disable the FPL feed using TOPGOLIK_FPL_ENABLED=false.

## OpenFootball allowlisted competitions

tr.1, en.1, en.2, en.3, en.4, de.1, de.2, es.1, es.2, it.1, it.2, fr.1, fr.2, at.1, at.2, be.1, nl.1, pt.1, sco.1, gr.1, au.1, mx.1, eg.1, ma.1, uefa.cl.
Availability varies by season; code allowlisting does not guarantee files exist or that underlying season data is complete.

## Other researched candidates (not automatically ingested)

| GitHub | Stars on audit | Reason |
|---|---:|---|
| hudl/open-data | 3720 | Advanced historic events; not a live match feed |
| probberechts/soccerdata | 2118 | Multi-source analytics; scraper stability and upstream rights unknown |
| openfootball/football.json | 1043 | Integrated archive |
| OpenLigaDB/OpenLigaDB-Samples | 179 | API integrated |
| apdmatos/sofascore-api | 36 | Unofficial and last pushed in 2022 |
| pseudo-r/Public-FotMob-API | 11 | Unofficial FotMob source; reliability and rights not established |
| Ryzellx/football-live-api | 4 | Claims 500+ leagues via FotMob; unverified uptime and redistribution rights |
| omkarcloud/flashscore-scraper | 2 | Claims unlimited scraping; no verified unrestricted data rights |

Do not mistake code licenses for upstream sports-data licenses. Restrict provider access to the Laravel server; protect source credentials; use caching, rate-limits, input validation, conservative retries and explicit API error states.

Product invariants: Turkish leagues ahead of all other leagues; 9 curated teams in exact configured order; no fake runtime matches, player identities, goals or news.
Source-scoped IDs prevent storage collisions but do not deduplicate the same real-world match across two providers; canonical ID mapping is a release gate.
Production needs actual source probes, monitoring, iOS release build, Android release build and tests for data timeliness and correctness.
