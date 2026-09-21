#!/usr/bin/env bash
# Deploys backend/ to production (codecell.site) over SSH.
#
#   ./deploy.sh            build, upload, migrate (after asking), rebuild caches, purge Varnish
#   ./deploy.sh --dry-run  build the tarball and check SSH access, change nothing on the server
#   ./deploy.sh --yes      don't ask before running pending migrations
#
# Needs an SSH key already authorized on the server (one-time: `ssh-copy-id codecell@SERVER_IP`).
# Production keeps its own .env, vendor/ and storage/ contents — none of them are uploaded or touched.
set -euo pipefail

SERVER_USER="${SERVER_USER:-codecell}"
SERVER_HOST="${SERVER_HOST:-SERVER_IP}"
APP_DIR="${APP_DIR:-/home/codecell/htdocs/shobuj-app}"
SITE_URL="${SITE_URL:-https://codecell.site}"
REMOTE="$SERVER_USER@$SERVER_HOST"

DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes) ASSUME_YES=1 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

cd "$(dirname "$0")"
[ -d backend ] || { echo "Run this from the repo root (backend/ not found)." >&2; exit 1; }

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15)
ssh_run() { ssh "${SSH_OPTS[@]}" "$REMOTE" "$@"; }

echo "==> Checking SSH access to $REMOTE"
if ! ssh_run "echo ok" >/dev/null 2>&1; then
  echo "Can't log in with an SSH key. Run once:  ssh-copy-id $REMOTE" >&2
  exit 1
fi

if [ -n "$(git status --porcelain backend 2>/dev/null)" ]; then
  echo "WARNING: backend/ has uncommitted changes — those will be deployed too."
  if [ "$ASSUME_YES" -ne 1 ] && [ "$DRY_RUN" -ne 1 ]; then
    read -r -p "Continue? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || exit 1
  fi
fi

TARBALL="$(mktemp -t agrohub-deploy.XXXXXX).tar.gz"
trap 'rm -f "$TARBALL"' EXIT

echo "==> Building tarball"
# COPYFILE_DISABLE stops macOS tar adding ._* metadata files to the archive.
COPYFILE_DISABLE=1 tar -czf "$TARBALL" \
  --exclude='backend/vendor' \
  --exclude='backend/.env' \
  --exclude='backend/tests' \
  --exclude='backend/docs' \
  --exclude='backend/node_modules' \
  --exclude='backend/.phpunit.cache' \
  --exclude='backend/storage/logs/*' \
  --exclude='backend/storage/app/*' \
  --exclude='backend/storage/framework/*/*' \
  --exclude='backend/storage/framework/testing' \
  --exclude='backend/bootstrap/cache/*.php' \
  --exclude='backend/database/*.sqlite' \
  --exclude='.DS_Store' \
  backend
echo "    $(du -h "$TARBALL" | cut -f1)"

if [ "$DRY_RUN" -eq 1 ]; then
  echo "==> Dry run: tarball built, SSH works. Nothing was uploaded or changed."
  exit 0
fi

echo "==> Uploading and extracting"
scp "${SSH_OPTS[@]}" -q "$TARBALL" "$REMOTE:/home/codecell/tmp/agrohub-deploy.tar.gz"
ssh_run "cd $APP_DIR && tar --warning=no-timestamp -xzf /home/codecell/tmp/agrohub-deploy.tar.gz --strip-components=1 && rm -f /home/codecell/tmp/agrohub-deploy.tar.gz && rm -rf storage/framework/testing"

echo "==> Installing dependencies"
ssh_run "cd $APP_DIR && php8.3 /usr/local/bin/composer install --no-dev --optimize-autoloader --no-interaction 2>&1 | tail -3"

echo "==> Pending migrations"
PENDING="$(ssh_run "cd $APP_DIR && php8.3 artisan migrate:status --pending --no-ansi 2>&1")"
echo "$PENDING"
# Each pending migration is a table row ending in "Pending"; the empty case prints
# "No pending migrations" (lowercase, mid-sentence), which this does not match.
if echo "$PENDING" | grep -qE '[. ]Pending[[:space:]]*$'; then
  if [ "$ASSUME_YES" -ne 1 ]; then
    read -r -p "Run ONLY the migrations listed above on production? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { echo "Stopped before migrating. Code is uploaded; caches not rebuilt."; exit 1; }
  fi
  ssh_run "cd $APP_DIR && php8.3 artisan migrate --force"
else
  echo "    none"
fi

echo "==> Rebuilding caches and purging Varnish"
ssh_run "cd $APP_DIR && php8.3 artisan optimize:clear >/dev/null && php8.3 artisan config:cache >/dev/null && php8.3 artisan route:cache >/dev/null && php8.3 artisan view:cache >/dev/null && php8.3 artisan event:cache >/dev/null && sudo /usr/bin/clpctlWrapper varnish-cache:purge --purge=all 2>&1 | tail -1"

echo "==> Smoke test"
for path in /up /privacy /api/v1/config/stripe-key; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "$SITE_URL$path" || true)"
  echo "    $path -> $code"
  [ "$code" = "200" ] || { echo "Unexpected status for $path — check storage/logs/laravel.log on the server." >&2; exit 1; }
done

echo "Deployed."
