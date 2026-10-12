#!/usr/bin/env bash
# Deploys backend/ to production (codecell.site) over SSH.
#
#   ./deploy.sh            build, upload, migrate (after asking), rebuild caches, purge Varnish
#   ./deploy.sh --dry-run  build the tarball and check SSH access, change nothing on the server
#   ./deploy.sh --yes      don't ask before running pending migrations
#
# Server details come from .deploy.env (not in git — copy .deploy.env.example).
# Needs an SSH key already authorized on the server (one-time: `ssh-copy-id <user>@<host>`).
# Production keeps its own .env, vendor/ and storage/ contents — none of them are uploaded or touched.
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck source=/dev/null
[ -f .deploy.env ] && . ./.deploy.env
: "${SERVER_USER:?Set SERVER_USER in .deploy.env (see .deploy.env.example)}"
: "${SERVER_HOST:?Set SERVER_HOST in .deploy.env}"
: "${APP_DIR:?Set APP_DIR in .deploy.env}"
: "${SITE_URL:?Set SITE_URL in .deploy.env}"
REMOTE_TMP="${REMOTE_TMP:-/home/$SERVER_USER/tmp}"
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
# -n: none of these read stdin, so leave it for the migration prompt below.
ssh_run() { ssh -n "${SSH_OPTS[@]}" "$REMOTE" "$@"; }

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
scp "${SSH_OPTS[@]}" -q "$TARBALL" "$REMOTE:$REMOTE_TMP/agrohub-deploy.tar.gz"
ssh_run "cd $APP_DIR && tar --warning=no-timestamp -xzf $REMOTE_TMP/agrohub-deploy.tar.gz --strip-components=1 && rm -f $REMOTE_TMP/agrohub-deploy.tar.gz && rm -rf storage/framework/testing"

echo "==> Checking for leftover files"
# Extracting over the old tree never removes files deleted locally, and
# Filament auto-discovers anything left under app/Filament (a removed admin
# page stays in the panel). Report them; moving them out is a manual step.
STALE="$(LC_ALL=C comm -13 \
  <(tar -tzf "$TARBALL" | sed -n 's#^backend/##p' | grep -E '^(app|config|routes|resources|database)/.*[^/]$' | LC_ALL=C sort) \
  <(ssh_run "cd $APP_DIR && find app config routes resources database -type f" | LC_ALL=C sort))"
if [ -n "$STALE" ]; then
  echo "    On the server but not in this deploy (move them out of $APP_DIR):"
  echo "$STALE" | sed 's/^/      /'
else
  echo "    none"
fi

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
# path:expected-status — the API check expects 401 (signed out), which
# proves Laravel booted and the API routes answer without needing a login.
for check in /up:200 /privacy:200 /api/v1/auth/me:401; do
  path="${check%%:*}"; want="${check##*:}"
  code="$(curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/json' "$SITE_URL$path" || true)"
  echo "    $path -> $code"
  [ "$code" = "$want" ] || { echo "Unexpected status for $path (wanted $want) — check storage/logs/laravel.log on the server." >&2; exit 1; }
done

echo "Deployed."
