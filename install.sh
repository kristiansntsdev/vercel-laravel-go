#!/usr/bin/env bash
# install.sh — Adds vercel-laravel-go files to an existing Laravel project.
# Usage (run in your Laravel project root):
#   curl -fsSL https://raw.githubusercontent.com/kristiansnts/vercel-laravel-go/main/install.sh | bash
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/kristiansnts/vercel-laravel-go/main/template"
TARGET_DIR="$(pwd)"

echo ""
echo "  vercel-laravel-go installer"
echo "  Adds Go+PHP-FPM serverless wrapper for Vercel to your Laravel project."
echo ""

# --- Verify we're in a Laravel project ---
if [ ! -f "$TARGET_DIR/artisan" ]; then
    echo "ERROR: artisan not found. Run this script from the root of your Laravel project." >&2
    exit 1
fi

FILES=(
    "api/main.go"
    "api/go.mod"
    "scripts/setup.sh"
    "scripts/pack.sh"
    "scripts/vercel-prepare.sh"
    ".github/workflows/deploy.yml"
    "vercel.json"
    ".vercelignore"
)

echo "==> Downloading files..."
for file in "${FILES[@]}"; do
    dir="$(dirname "$file")"
    mkdir -p "$TARGET_DIR/$dir"

    # Don't overwrite vercel.json if it already exists
    if [ -f "$TARGET_DIR/$file" ] && [ "$file" = "vercel.json" ]; then
        echo "  SKIP  $file (already exists — review manually)"
        continue
    fi

    curl -fsSL "$REPO_RAW/$file" -o "$TARGET_DIR/$file"
    echo "  OK    $file"
done

echo ""
echo "==> Patching .gitignore..."
GITIGNORE="$TARGET_DIR/.gitignore"
touch "$GITIGNORE"
for entry in "api/php-fpm-bin" "api/vendor.tar.gz" "api/laravel/"; do
    if ! grep -qF "$entry" "$GITIGNORE"; then
        echo "$entry" >> "$GITIGNORE"
        echo "  Added: $entry"
    fi
done

chmod +x "$TARGET_DIR/scripts/setup.sh"
chmod +x "$TARGET_DIR/scripts/pack.sh"
chmod +x "$TARGET_DIR/scripts/vercel-prepare.sh"

echo ""
echo "✅ Done! Next steps:"
echo ""
echo "  1. Pack your vendor directory:"
echo "     bash scripts/pack.sh"
echo ""
echo "  2. Add your Vercel secrets to GitHub:"
echo "     VERCEL_TOKEN, VERCEL_ORG_ID, VERCEL_PROJECT_ID"
echo ""
echo "  3. Set APP_KEY, DB_*, REDIS_URL and other secrets in Vercel dashboard."
echo ""
echo "  4. Push to main — GitHub Actions will deploy automatically."
echo "     (vercel-prepare.sh runs at build time to bundle PHP-FPM + Laravel files)"
echo ""
echo "  See README for details: https://github.com/kristiansnts/vercel-laravel-go"
echo ""
echo "  ⭐ If this helped you, don't forget to give us a star!"
echo "     https://github.com/kristiansnts/vercel-laravel-go"
echo ""
