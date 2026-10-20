# Architecture decisions

- Flutter is an API-only consumer. No provider credentials or endpoints are exposed through mobile source code.
- The Laravel API reads PostgreSQL; scheduled ingestion fetches scoreboards from the provider and writes idempotent upserts.
- Remote IDs are namespaced by provider. No fragile cross-provider team merging is performed.
- Public read endpoints are IP-rate-limited. Ingestion is a separate server-side Artisan command.
- Scoreboard requests use an allow-listed upstream hostname and fixed URL construction. League identifiers must match an ASCII slug pattern.
- Redis is used for queues/cache/lock primitives. PostgreSQL remains the source of truth.
- Locale order is de, fr, it, en. The device locale is selected where supported; unsupported locales fall back to English.

The provider registry (`TOPGOLIK_ESPN_LEAGUES`) is a list of provider-defined external identifiers, not synthetic fixture data. Expand it only after validating actual coverage.
