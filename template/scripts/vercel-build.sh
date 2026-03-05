#!/usr/bin/env bash
# vercel-build.sh — Runs during Vercel's build step (before Go compilation).
# Downloads PHP CLI + Composer, installs deps, packs vendor, downloads PHP-FPM.
set -euo pipefail

PHP_VERSION="8.4.18"
BASE_URL="https://dl.static-php.dev/static-php-cli/bulk"

mkdir -p api/bin

# 1. Download static PHP CLI binary (used to run Composer)
echo "==> [1/4] Downloading PHP ${PHP_VERSION} CLI..."
curl -fsSL "$BASE_URL/php-${PHP_VERSION}-cli-linux-x86_64.tar.gz" | tar -xz -C /tmp
PHP_BIN="/tmp/php"
chmod +x "$PHP_BIN"

# 2. Download Composer
echo "==> [2/4] Downloading Composer..."
curl -fsSL https://getcomposer.org/installer | "$PHP_BIN" -- --install-dir=/tmp --filename=composer
COMPOSER="/tmp/composer"

# 3. Install production dependencies and pack vendor
echo "==> [3/4] Installing Composer dependencies..."
"$PHP_BIN" "$COMPOSER" install \
    --no-dev \
    --no-interaction \
    --no-scripts \
    --prefer-dist \
    --optimize-autoloader \
    --classmap-authoritative

echo "==> Packing vendor.tar.gz..."
tar -czf api/vendor.tar.gz \
    --exclude='vendor/*/tests' \
    --exclude='vendor/*/Tests' \
    --exclude='vendor/*/Test' \
    --exclude='vendor/*/doc' \
    --exclude='vendor/*/docs' \
    --exclude='vendor/*/.git' \
    vendor/

echo "==> vendor.tar.gz size: $(du -sh api/vendor.tar.gz | cut -f1)"

# 4. Download static PHP-FPM binary (embedded into Go binary for runtime)
echo "==> [4/4] Downloading PHP-FPM ${PHP_VERSION}..."
curl -fsSL "$BASE_URL/php-${PHP_VERSION}-fpm-linux-x86_64.tar.gz" | tar -xz -C /tmp
cp /tmp/php-fpm api/bin/php-fpm
chmod +x api/bin/php-fpm

echo "==> Build assets ready:"
ls -lh api/vendor.tar.gz api/bin/php-fpm
