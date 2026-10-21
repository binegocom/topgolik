# API-Football $0 integration in Topgolik

Official documentation: https://api-sports.io/documentation/football/v3
Free plan and quota: https://www.api-football.com/pricing
Terms and image rights: https://www.api-football.com/terms

## What is and is not guaranteed

- Free tier: 100 requests/day. Free account may not expose the requested 2026 season for every Turkish league or group.
- API key is a server-only secret. Never store the key in Flutter, GitHub, screenshots or this chat.
- The provider permits application development but prohibits unauthorized raw data resale. Club badges are third-party intellectual property; the feed does NOT license them for every commercial use.
- The implementation is optional and disabled by default; ESPN, OpenLigaDB, OpenFootball and FPL continue functioning without API-Football.
- Data-source-scope match IDs remain isolated. Repeated real-world fixtures across ESPN/API-Football require approved cross-source mapping, never name-only merging.

## MacBook simulator onboarding

1. Create a free account: https://dashboard.api-football.com/ (Account -> My Access).
2. Edit local backend/.env, never backend/.env.example, with these values:

    TOPGOLIK_API_FOOTBALL_ENABLED=true
    TOPGOLIK_API_FOOTBALL_KEY=YOUR_PRIVATE_KEY
    TOPGOLIK_API_FOOTBALL_COUNTRY=Turkey
    TOPGOLIK_API_FOOTBALL_DAILY_BUDGET=80
    TOPGOLIK_API_FOOTBALL_MINUTE_BUDGET=8
    TOPGOLIK_API_FOOTBALL_AUTO_SYNC=false

3. Rebuild Laravel Docker so env and new source code are actually loaded:

    docker compose -f compose.simulator.yaml up -d --build api scheduler gateway
    docker compose -f compose.simulator.yaml exec api php artisan migrate --force
    docker compose -f compose.simulator.yaml exec api php artisan config:clear

4. Discover actual available Turkey leagues for the selected season and import up to 10 club catalogs:

    docker compose -f compose.simulator.yaml exec api php artisan api-football:sync --country=Turkey --season=2026 --max-leagues=10

5. To import fixtures for one **discovered** numeric league ID:

    docker compose -f compose.simulator.yaml exec api php artisan api-football:sync --country=Turkey --season=2026 --league=DISCOVERED_NUMERIC_ID --fixtures --date=today

6. Verify results using the local gateway API:

    curl -sS http://127.0.0.1:YOUR_DOCKER_PORT/api/v1/leagues
    curl -sS 'http://127.0.0.1:YOUR_DOCKER_PORT/api/v1/search/teams?q=Amedspor'

## Implementation

- First discover source leagues via leagues?country=Turkey&season=2026. Only season-confirmed API IDs are stored.
- Import teams independently via teams?league=ID&season=2026, preserving original names, IDs and HTTPS image URLs.
- Only when --fixtures is specified, import source fixtures and score status via fixtures?league=ID&season=2026&date=YYYY-MM-DD&timezone=UTC.
- SQL records are provider-scoped. No unavailable league, match, athlete or logo is synthesized.
- The bulk CLI spaces requests eight seconds apart to respect the default 8/min budget. A ten-league catalog import can therefore take more than a minute. Shared Laravel cache lock limits the app to 80 requests/day and 8/min by default, below the upstream free cap. No automatic retries.
- If the API returns an error or a paginated response, stop instead of persisting incomplete data.
- Opt-in TOPGOLIK_API_FOOTBALL_AUTO_SYNC=true schedules **catalog only** updates once daily. A 100/day quota cannot deliver continuous worldwide live matches.

## Production caveats

The GitHub CI tests synthetic fixture inputs and quota controls. They cannot verify what your personal API-Football free account exposes today. Always run the above commands on your Mac with your own key and inspect real output before claiming Turkey 1. Lig / 2. Lig / 3. Lig coverage. Confirm commercial logo usage with rightsholders.
