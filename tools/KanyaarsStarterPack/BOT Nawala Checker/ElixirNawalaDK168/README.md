# ElixirNawalaDK168

Platform monitoring domain (SFLINK) + notifikasi Telegram berbasis Elixir/Phoenix.

## Production Deploy (Docker + Caddy)

README ini difokuskan untuk deploy production ke VPS.

### Arsitektur Container
1. `app`: Phoenix release (`mix release`)
2. `db`: PostgreSQL
3. `caddy`: reverse proxy + auto HTTPS (Let's Encrypt)

### File Penting Deploy
1. `Dockerfile`
2. `docker-compose.yml`
3. `Caddyfile`
4. `.env.example`
5. `docker/entrypoint.sh`

## Prasyarat VPS
1. Docker + Docker Compose sudah terpasang
2. Domain aktif (A record) mengarah ke IP VPS
3. Port `80` dan `443` terbuka di firewall

## Setup Cepat

### 1. Clone dan masuk ke project
```bash
git clone <repo>
cd ElixirNawalaDK168
```

### 2. Siapkan environment
```bash
cp .env.example .env
```

Generate secret:
```bash
mix phx.gen.secret
```

Isi file `.env`:
1. `CADDY_DOMAIN` = domain production (contoh: `app.domainkamu.com`)
2. `PHX_HOST` = domain yang sama
3. `SECRET_KEY_BASE` = hasil `mix phx.gen.secret`
4. `DATABASE_URL` (default compose sudah siap untuk service `db`)
5. Opsional: `TELEGRAM_BOT_TOKEN`, `SFLINK_API_TOKEN`

### 3. Build dan jalankan
```bash
docker compose up -d --build
```

### 4. Cek status dan log
```bash
docker compose ps
docker compose logs -f app
docker compose logs -f caddy
```

### 5. Akses aplikasi
`https://YOUR_DOMAIN`

## Database Migration

Migration dijalankan otomatis saat container `app` start lewat `docker/entrypoint.sh`.

Jika ingin skip migration (misalnya untuk troubleshooting):
```bash
SKIP_MIGRATIONS=true docker compose up -d app
```

## Update Deploy (Rolling Sederhana)
```bash
git pull
docker compose up -d --build
```

## Backup PostgreSQL
```bash
docker compose exec -T db pg_dump -U postgres elixir_nawala_dk168_prod > backup.sql
```

Restore:
```bash
cat backup.sql | docker compose exec -T db psql -U postgres -d elixir_nawala_dk168_prod
```

## Troubleshooting

1. Sertifikat HTTPS tidak terbit:
   Pastikan DNS domain sudah benar dan port `80/443` tidak diblok.
2. App gagal start karena env:
   Cek `SECRET_KEY_BASE`, `PHX_HOST`, dan `DATABASE_URL` di `.env`.
3. App loop restart:
   Cek log:
   - `docker compose logs -f app`
   - `docker compose logs -f db`
   - `docker compose logs -f caddy`

## Default Admin Seed
1. Email: `admin@dk168.local`
2. Password: `ChangeMe123!`

Override sebelum setup awal database:
1. `DEFAULT_ADMIN_EMAIL`
2. `DEFAULT_ADMIN_PASSWORD`
