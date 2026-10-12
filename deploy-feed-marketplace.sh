#!/usr/bin/env bash
# Deploys the Home feed's marketplace listings (GET /feed/marketplace) to
# production: one new controller plus its route. No migration.
# Backs up the server's routes/api.php first:
#   ssh codecell@SERVER_IP 'cd /home/codecell/htdocs/shobuj-app && tar -xzf <backup path printed below>'
set -euo pipefail
cd "$(dirname "$0")/backend"

REMOTE=codecell@SERVER_IP
APP=/home/codecell/htdocs/shobuj-app

NEW_FILES=(
  app/Http/Controllers/Api/V1/FeedMarketplaceController.php
)
CHANGED=(
  routes/api.php
)
# The server's routes/api.php when this deploy was prepared; the local copy
# differs from it only by the /feed/marketplace route.
ROUTES_SERVER_MD5=dacc324f7aa54dd89c03968a079d9d02

remote() { ssh -n "$REMOTE" "$@"; }

echo "==> Checking the server's routes/api.php is unchanged"
actual="$(remote "md5sum $APP/routes/api.php" | cut -d' ' -f1)"
[ "$actual" = "$ROUTES_SERVER_MD5" ] || { echo "routes/api.php on the server changed since this deploy was prepared - stopping." >&2; exit 1; }
echo "    ok"

echo "==> Backing up the server's current copies"
remote "cd $APP && mkdir -p /home/codecell/backups && B=/home/codecell/backups/feed-marketplace-\$(date +%Y%m%d-%H%M%S).tar.gz && tar -czf \$B ${CHANGED[*]} && echo \"    \$B\""

echo "==> Uploading the new controller, then the route"
COPYFILE_DISABLE=1 tar --no-xattrs -cf - "${NEW_FILES[@]}" | ssh "$REMOTE" "cd $APP && tar --warning=no-timestamp -xf -"
remote "cd $APP && for f in ${NEW_FILES[*]}; do php8.3 -l \$f >/dev/null || { echo \"SYNTAX ERROR in \$f\"; exit 1; }; done && echo '    syntax ok'"
COPYFILE_DISABLE=1 tar --no-xattrs -cf - "${CHANGED[@]}" | ssh "$REMOTE" "cd $APP && tar --warning=no-timestamp -xf -"
remote "cd $APP && for f in ${CHANGED[*]}; do php8.3 -l \$f >/dev/null || { echo \"SYNTAX ERROR in \$f - restore the backup above\"; exit 1; }; done && echo '    ok'"

echo "==> Autoloader (new class), caches and Varnish"
remote "cd $APP && php8.3 /usr/local/bin/composer dump-autoload --optimize --no-dev --no-interaction 2>&1 | tail -1"
remote "cd $APP && php8.3 artisan optimize:clear >/dev/null && php8.3 artisan config:cache >/dev/null && php8.3 artisan route:cache >/dev/null && php8.3 artisan view:cache >/dev/null && php8.3 artisan event:cache >/dev/null && sudo /usr/bin/clpctlWrapper varnish-cache:purge --purge=all 2>&1 | tail -1"
remote "cd $APP && php8.3 artisan route:list --path=feed/marketplace --no-ansi | grep -c marketplace | sed 's/^/    marketplace routes: /'"

echo "==> Smoke test"
for path in /up /privacy /api/v1/config/stripe-key; do
  code="$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' "https://codecell.site$path" || true)"
  echo "    $path -> $code"
  [ "$code" = "200" ] || { echo "Unexpected status for $path - check storage/logs/laravel.log on the server." >&2; exit 1; }
done
# Unauthenticated, so 401 means the route exists and the app booted.
code="$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' -H 'Accept: application/json' "https://codecell.site/api/v1/feed/marketplace" || true)"
echo "    /api/v1/feed/marketplace (no token) -> $code"
[ "$code" = "401" ] || { echo "Expected 401 from the new route." >&2; exit 1; }

echo "Deployed."
