# vercel-laravel-go

> Deploy Laravel 11/12 (including heavy Filament apps) on Vercel for free — without hitting the 250MB vendor size limit.

## The Problem

[vercel-php](https://github.com/juicyfx/vercel-php) is great, but Vercel serverless functions have a **250MB unzipped size limit**. Heavy apps using Filament, Dompdf, or many Composer packages easily exceed this.

`SESSION_DRIVER=cookie` on Vercel also causes **HTTP 494 (Request Header Too Large)** errors because Filament stores too much data in the encrypted session cookie.

## The Solution

This project adds a **Go serverless function** to your Laravel project that:

1. Uses a **bundled static PHP-FPM binary** (downloaded at build time, not at runtime)
2. Extracts `vendor.tar.gz` to `/tmp/vendor` (compressed ~30MB vs 200MB+ raw)
3. Creates symlinks so Composer's autoloader resolves app classes correctly
4. Redirects Laravel's storage path to writable `/tmp/storage`
5. Starts PHP-FPM on a Unix socket
6. Proxies every HTTP request via FastCGI to PHP-FPM

## Requirements

- Laravel 11 or 12
- PHP 8.4 (bundled via static binary — no server PHP needed)
- [Upstash Redis](https://upstash.com) (free tier) — required for sessions when using Filament or Livewire
- Vercel Hobby plan or higher

## Quick Start

Run in your Laravel project root:

```bash
curl -fsSL https://raw.githubusercontent.com/kristiansntsdev/vercel-laravel-go/main/install.sh | bash
```

Then follow the printed steps:

```bash
# 1. Pack vendor into api/vendor.tar.gz and commit it (required — Vercel needs it at build time)
bash scripts/pack.sh
git add api/vendor.tar.gz
git commit -m "chore: add vendor.tar.gz for Vercel deployment"
git push
```

> **Why commit `api/vendor.tar.gz`?** Vercel's build environment doesn't have PHP/Composer, so the packed vendor must be pre-built and included in the repository. It's ~30MB — well within GitHub's 100MB file limit. Only re-run `pack.sh` and recommit when `composer.json` changes.

## Environment Variables

### Set in Vercel Dashboard (secrets — never commit these)

| Variable | Description |
|---|---|
| `APP_KEY` | `php artisan key:generate --show` |
| `DB_CONNECTION` | `pgsql` or `mysql` |
| `DB_HOST` | Your database host |
| `DB_PORT` | Database port |
| `DB_DATABASE` | Database name |
| `DB_USERNAME` | Database username |
| `DB_PASSWORD` | Database password |
| `REDIS_URL` | Upstash Redis URL (`rediss://default:pass@host:port`) |
| `REDIS_CLIENT` | Must be `predis` (Laravel's default `phpredis` extension is not available) |

### Pre-configured in `vercel.json`

```
APP_ENV=production
APP_DEBUG=false
APP_URL=https://your-app.vercel.app   ← set to your actual domain (custom or .vercel.app)

# All caches redirected to writable /tmp
APP_CONFIG_CACHE=/tmp/config.php
APP_EVENTS_CACHE=/tmp/events.php
APP_PACKAGES_CACHE=/tmp/packages.php
APP_ROUTES_CACHE=/tmp/routes.php
APP_SERVICES_CACHE=/tmp/services.php
VIEW_COMPILED_PATH=/tmp/views

# Redis sessions (required for Filament/Livewire — cookie driver causes 494 errors)
SESSION_DRIVER=redis
SESSION_SECURE_COOKIE=true
REDIS_CLIENT=predis
REDIS_DB=0
REDIS_CACHE_DB=0
CACHE_DRIVER=redis
CACHE_STORE=redis

LOG_CHANNEL=stderr
```

## Adding New Composer Dependencies

When you add a new package with `composer require`, rebuild and recommit `vendor.tar.gz`:

```bash
# After composer require some/package...
bash scripts/pack.sh
git add api/vendor.tar.gz
git commit -m "chore: update vendor.tar.gz"
git push
```

**Using GitHub Actions CI?** The CI workflow runs `composer install` and `pack.sh` automatically — but the result is not committed back to git. You still need to commit `vendor.tar.gz` locally after dependency changes, OR let CI deploy directly via `vercel deploy --prod` (it uploads the file without needing it in git).

## Upstash Redis Setup (required for Filament/Livewire)

1. Go to [upstash.com](https://upstash.com) → Create a free Redis database
2. Copy the **Redis URL** (format: `rediss://default:password@host:port`)
3. Add to Vercel dashboard: `REDIS_URL=rediss://...`
4. Add `predis/predis` to your project: `composer require predis/predis`
5. Repack vendor: `bash scripts/pack.sh`

> **Why not `SESSION_DRIVER=cookie`?** Filament stores too much data in the session, causing the cookie to exceed Vercel's ~8KB header limit (HTTP 494).

> **Why not `SESSION_DRIVER=file`?** Each Vercel invocation gets a fresh `/tmp` — file sessions don't persist across requests.

## Database

Vercel functions have **no static IP**. Your database must either:
- Allow connections from `0.0.0.0/0` (secure with strong password + SSL), or
- Use a serverless-compatible DB: [Neon](https://neon.tech), [Supabase](https://supabase.com), [PlanetScale](https://planetscale.com)

## Reducing Cold Starts

Cold starts take ~2–3s (vendor extraction + PHP-FPM startup). The PHP-FPM binary is now bundled at build time so there's no download penalty.

**Keep the container warm with a free external pinger:**
- [cron-job.org](https://cron-job.org) — free, ping every 5 min
- [UptimeRobot](https://uptimerobot.com) — free, monitor every 5 min (also gives uptime alerts)

Add a monitor pointing to your app URL — it'll keep the container warm and eliminate cold starts for active apps.

> Vercel's built-in cron (`vercel.json` `crons`) requires Pro plan for intervals shorter than daily.

## GitHub Actions (CI/CD)

The installer adds `.github/workflows/deploy.yml`. Add these secrets to your GitHub repo:

| Secret | Where to find it |
|---|---|
| `VERCEL_TOKEN` | vercel.com → Settings → Tokens |
| `VERCEL_ORG_ID` | Personal account: vercel.com → Settings → General → "Your ID"<br>**Team project**: vercel.com/teams/YOUR_TEAM/settings → General → "Team ID" |
| `VERCEL_PROJECT_ID` | vercel.com → Project → Settings → General → "Project ID" |

Push to `main` → automatic deployment. The workflow runs `composer install`, `bash scripts/pack.sh`, then `vercel deploy --prod` (which triggers `npm run build && bash scripts/vercel-prepare.sh` at build time). No GitHub Releases or `VENDOR_URL` needed.

## Files Added to Your Project

```
your-laravel-project/
├── api/
│   ├── main.go               # Go serverless function (FastCGI proxy)
│   ├── go.mod
│   └── vendor.tar.gz         # Compressed vendor — committed to git, built by pack.sh
├── scripts/
│   ├── setup.sh              # Downloads static PHP-FPM binary (optional, local use only)
│   ├── pack.sh               # Packs vendor/ into api/vendor.tar.gz
│   └── vercel-prepare.sh     # Runs at Vercel build time: copies Laravel source + downloads PHP-FPM binary
├── vercel.json
├── .vercelignore
└── .github/
    └── workflows/
        └── deploy.yml
```

> `api/php-fpm-bin` and `api/laravel/` are generated at **Vercel build time** by `vercel-prepare.sh` and are gitignored — you don't commit them.

## How It Works (Technical Details)

### Why `api/laravel/` directory?

`@vercel/go`'s `includeFiles` is relative to the function source directory (`api/`). To include Laravel source files, `scripts/vercel-prepare.sh` copies them into `api/laravel/` during build. At runtime they're at `/var/task/laravel/`.

### Why symlinks in `/tmp`?

Composer's autoloader computes `$baseDir` as two levels up from `vendor/composer/` — so when vendor is at `/tmp/vendor/`, it resolves app classes as `/tmp/app/`, `/tmp/config/`, etc. The Go bootstrap creates symlinks `/tmp/app → /var/task/laravel/app` etc. so autoloading works.

### Why override `PackageManifest`?

Laravel's `PackageManifest` defaults `$vendorPath` to `$basePath.'/vendor'` = `/var/task/laravel/vendor` (doesn't exist). The PHP entry overrides it to `/tmp/vendor` before `handleRequest()` so all service providers register correctly.

### Why `useStoragePath('/tmp/storage')`?

`/var/task` is read-only on Vercel. All writes (logs, compiled views, sessions if using file driver) must go to `/tmp`. The Go bootstrap pre-creates the required subdirectories.

## PHP Version & Extensions

Uses PHP 8.4 static binary from [static-php-cli](https://github.com/crazywhalecc/static-php-cli). To change the version, update `PHP_FPM_URL` in `vercel.json`.

Note: PHP 8.4 is required if your dependencies require `>=8.4` (e.g., Symfony 8.x, openspout 4.x).

## Limitations

- **No persistent filesystem** — use a managed database
- **Cold starts** (~2–3s) — vendor extraction + PHP-FPM startup; PHP binary is bundled so no download penalty. Use an external pinger to keep warm
- **No queue workers** — run on a separate service (Railway, Fly.io, or Vercel cron for simple tasks)
- **No cron** — use an external scheduler or Vercel Pro cron
- **Vercel Hobby max duration** — 60s per request
- **No static IP** — use a database that accepts all IPs or a serverless-native DB

## License

MIT
