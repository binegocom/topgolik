# Topgolik

Global football fixtures and live scores for iOS and Android.

**Status:** Foundational vertical slice under review. Not released to production. Live data depends on third-party availability and data rights.

## Architecture

- `app/` — Flutter application (German, French, Italian, English; system locale, English fallback).
- `backend/` — Laravel 13 REST API with PostgreSQL, Redis and scheduled ESPN score ingestion.
- `docs/` — architecture, data provenance and release gates.

**No generated/fake match records are served.** Match lists come from validated upstream provider responses stored in PostgreSQL. If upstream coverage is unavailable, the API returns an empty result rather than fabricated scores.

## Local development

Requirements: Docker Compose, Flutter stable (Dart 3.9+), Android SDK / Xcode.

```sh
cp backend/.env.example backend/.env
php -r '$p="backend/.env"; $v=file_get_contents($p); $key="base64:".base64_encode(random_bytes(32)); file_put_contents($p,preg_replace("/^APP_KEY=.*$/m","APP_KEY=".$key,$v));'
docker compose up -d --build
# In another terminal, only for a new development database:
docker compose exec api php artisan migrate --force
docker compose exec api php artisan matches:sync --date=today
curl -fsS http://127.0.0.1:8080/api/v1/health

cd app
flutter pub get
flutter create --platforms=android,ios --project-name topgolik --org com.binego .
flutter analyze
flutter test
flutter run --dart-define=TOPGOLIK_API_URL=http://10.0.2.2:8080/api/v1
```

For the iOS simulator use `--dart-define=TOPGOLIK_API_URL=http://127.0.0.1:8080/api/v1`; physical devices need a reachable HTTPS domain. The platform folders are generated from the app's source on first setup, not checked in at this stage.

## Operational warnings

- ESPN's soccer endpoints used here are undocumented and not guaranteed stable or commercially licensed. Obtain distribution rights or switch to a licensed provider before publishing.
- The free OpenLigaDB endpoint is an alternative candidate but is not yet implemented as a production adapter.
- API responses are anonymous and read-only, with no user account or server-side favorites in this milestone.
- See `docs/RELEASE_GATES.md` for the remaining checks before release.
