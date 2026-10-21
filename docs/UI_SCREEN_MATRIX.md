# Topgolik mobile screen implementation

## Reference UI system

The attached Topgolik promotional artwork is a visual reference, not a dataset or a production image license. The implemented interface adopts its midnight navy background, neon-green emphasis, red live state, football card layout, compact date navigation and five-destination bottom bar. It intentionally does not embed player photos, team shields or editorial headlines from the artwork.

## Route hierarchy / backed data

| Route / screen | Backend integration | Status |
| --- | --- | --- |
| Main / Dashboard | GET /api/v1/matches, existing saved matches | Implemented |
| Main / Leagues | GET /api/v1/leagues | Implemented |
| League detail / Fixtures | GET /api/v1/matches?league=...&date=... | Implemented |
| League detail / Standings | Standings endpoint does not exist | Explicitly unavailable |
| Main / Matches | GET /api/v1/matches date, league, status + pages | Implemented |
| Main / Teams | GET /api/v1/search/teams | Implemented |
| Team search | GET /api/v1/search/teams?q=... | Existing, styled |
| Team matches | GET /api/v1/teams/:id/matches | Existing, styled |
| Main / More | Local navigation | Implemented |
| Match detail / Overview | GET /api/v1/matches/:id | Implemented |
| Match detail / Statistics | Missing provider / API contract | Explicitly unavailable |
| Match detail / Lineups | Missing provider / API contract | Explicitly unavailable |
| Match detail / Commentary | Missing provider / API contract | Explicitly unavailable |
| News / Transfers / Videos / Trending | No verified feed or licensing | Explicitly unavailable |
| Notifications | Push pipeline not yet implemented | Explicitly unavailable |
| Settings | App information; no account is required | Implemented |
| Authentication, profile, player page | No accounts or player model in backend | Not implemented |

No sample fixture, article, player, result, standings position, transfer or notification is generated in runtime.

## Product invariants

- Turkish leagues precede foreign competitions on both the matches and league APIs, before pagination.
- The nine recommended teams are returned by the backend in exactly the configured product order.
- German is the source localization, French, Italian and English are supported, and unsupported device locales fall back to English.
- All screen data uses the existing Laravel API with HTTPS in production. User-side local match bookmarks remain local and are not presented as cloud-synced.
- UI does not claim push, standings, statistics, editorial articles or sign-in are functional until real provider adapters and backend contracts exist.

## Remaining production gates

1. Integrate and validate approved provider data for standings, goals, lineups, players and news.
2. Implement a real notification delivery/permission/follow pipeline and retention controls.
3. Add signed platform runners, device screenshot/golden tests and visual QA at multiple viewport widths.
4. Validate production deployment, uptime, monitoring, data sources and redistribution rights.
5. Complete iOS simulator/device and store-ready release validation.

A successful debug APK in CI is not the same as a production-certified app.

## Premier League player statistics

`More > Player statistics` now queries the existing Laravel read-only Fantasy Premier League endpoint. The screen supports searching players/clubs and displays actual source-provided goals, assists, minutes and xG. Null statistics remain unavailable rather than being guessed. This feed is expressly limited to the English Premier League, and the upstream's redistribution rights and live uptime still require release approval.
