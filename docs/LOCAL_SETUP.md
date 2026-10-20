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
