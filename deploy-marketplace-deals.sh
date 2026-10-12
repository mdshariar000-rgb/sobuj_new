#!/usr/bin/env bash
# Deploys the marketplace deal fixes to production:
#  - offer notifications (swap_offer_received / swap_offer_updated)
#  - the listing follows the deal (reserved on accept, back to active on
#    cancel, completed on completion, other open offers closed)
#  - reviews only after a completed deal (can_review on GET /listings/{id})
# No migration, no new classes, no route changes. Backs up every server file
# it replaces:
#   ssh codecell@SERVER_IP 'cd /home/codecell/htdocs/shobuj-app && tar -xzf <backup path printed below>'
set -euo pipefail
cd "$(dirname "$0")/backend"

REMOTE=codecell@SERVER_IP
APP=/home/codecell/htdocs/shobuj-app

CHANGED=(
  app/Enums/NotificationType.php
  app/Http/Controllers/Api/V1/SwapOfferController.php
  app/Http/Controllers/Api/V1/ListingReviewController.php
  app/Http/Controllers/Api/V1/ListingController.php
  app/Http/Resources/ListingResource.php
  app/Models/Listing.php
)
# The server's copies of CHANGED when this deploy was prepared (same order);
# each local file differs from them only by these fixes.
EXPECTED_MD5=(
  93ab00b0dc7ae815527f99251e3f677c
  c0a5bfee5abd1e25833e914ab3576724
  896af74fc34c322a581f8c03d52920e1
  7b7975879d0ccbde691355f7b72261c9
  7f796093e98c57692dc02aad93dd77e0
  1f39ed0c0fb9d2e5ca10b4927e9f4bd8
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
remote "cd $APP && mkdir -p /home/codecell/backups && B=/home/codecell/backups/marketplace-deals-\$(date +%Y%m%d-%H%M%S).tar.gz && tar -czf \$B ${CHANGED[*]} && echo \"    \$B\""

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
