# Local setup (macOS)

Clone the repository, create and secure your local environment file:

```sh
git clone https://github.com/binegocom/topgolik.git
cd topgolik
cp backend/.env.example backend/.env
php -r '$p="backend/.env"; $v=file_get_contents($p); $key="base64:".base64_encode(random_bytes(32)); file_put_contents($p,preg_replace("/^APP_KEY=.*$/m","APP_KEY=".$key,$v));'
docker compose up --build -d
docker compose exec api php artisan migrate --force
docker compose exec api php artisan matches:sync --date=today
curl -fsS http://127.0.0.1:8080/api/v1/health
```

For a production setup do **not** reuse the development Postgres password. Use a private reverse proxy with HTTPS, health checks, backups and provider rate limiting; keep database/Redis private.

To run the app, open `app/`, install Flutter dependencies and generate platform runners once with `flutter create --platforms=android,ios --project-name topgolik --org com.binego .`.

## Debug build artifacts

GitHub Actions uploads a `topgolik-android-debug` APK and an unsigned `topgolik-ios-simulator` application tarball after successful checks. In GitHub, open **Actions**, select a successful main-branch workflow run, and download the artifact under **Artifacts**. Artifacts expire after seven days. iOS Simulator packages only run in the simulator; they are **not** signed iPhone IPAs or App Store builds.

The Android debug APK is not a production release or store-ready AAB. Actual signed releases require verified `applicationId`, bundle identifiers, keystores/certificates, privacy manifests, in-app assets and connected live API infrastructure.
