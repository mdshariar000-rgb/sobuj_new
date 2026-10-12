#!/usr/bin/env bash
# Deploys the richer public profile (GET /users/{id}: posts/listing counts,
# seller rating, completed deals). No migration, no new classes or routes.
# Backs up every server file it replaces:
#   ssh codecell@SERVER_IP 'cd /home/codecell/htdocs/shobuj-app && tar -xzf <backup path printed below>'
set -euo pipefail
cd "$(dirname "$0")/backend"

REMOTE=codecell@SERVER_IP
APP=/home/codecell/htdocs/shobuj-app

CHANGED=(
  app/Http/Controllers/Api/V1/UserController.php
  app/Http/Resources/UserResource.php
)
# The server's copies of CHANGED when this deploy was prepared (same order);
# each local file differs from them only by the profile fields.
EXPECTED_MD5=(
  bb10769ec86b84cd2335319cfdc820dd
  5d020938c83a3c84f7fb3c5c93342736
)

remote() { ssh -n "$REMOTE" "$@"; }

echo "==> Checking the server's files are unchanged since this was prepared"
i=0
for f in "${CHANGED[@]}"; do
  actual="$(remote "md5sum $APP/$f" | cut -d' ' -f1)"
  [ "$actual" = "${EXPECTED_MD5[$i]}" ] || { echo "$f on the server changed since this deploy was prepared - stopping." >&2; exit 1; }
  i=$((i + 1))
done
echo "    ok"

echo "==> Backing up the server's current copies"
remote "cd $APP && mkdir -p /home/codecell/backups && B=/home/codecell/backups/profile-stats-\$(date +%Y%m%d-%H%M%S).tar.gz && tar -czf \$B ${CHANGED[*]} && echo \"    \$B\""

echo "==> Uploading ${#CHANGED[@]} changed files"
COPYFILE_DISABLE=1 tar --no-xattrs -cf - "${CHANGED[@]}" | ssh "$REMOTE" "cd $APP && tar --warning=no-timestamp -xf -"

echo "==> Syntax check on the server"
remote "cd $APP && for f in ${CHANGED[*]}; do php8.3 -l \$f >/dev/null || { echo \"SYNTAX ERROR in \$f - restore the backup above\"; exit 1; }; done && echo '    ok'"

echo "==> Rebuilding caches and purging Varnish"
remote "cd $APP && php8.3 artisan optimize:clear >/dev/null && php8.3 artisan config:cache >/dev/null && php8.3 artisan route:cache >/dev/null && php8.3 artisan view:cache >/dev/null && php8.3 artisan event:cache >/dev/null && sudo /usr/bin/clpctlWrapper varnish-cache:purge --purge=all 2>&1 | tail -1"

echo "==> Smoke test"
for path in /up /privacy /api/v1/config/stripe-key; do
  code="$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' "https://codecell.site$path" || true)"
  echo "    $path -> $code"
  [ "$code" = "200" ] || { echo "Unexpected status for $path - check storage/logs/laravel.log on the server." >&2; exit 1; }
done

echo "Deployed."
