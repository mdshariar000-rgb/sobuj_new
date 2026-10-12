#!/usr/bin/env bash
# Deploys follows, listing reviews, onboarding suggestions and the
# "joined groups + followed first" Home feed to production.
# Backs up every server file it replaces:
#   ssh codecell@SERVER_IP 'cd /home/codecell/htdocs/shobuj-app && tar -xzf <backup path printed below>'
# The two migrations only create new tables (user_follows, listing_reviews);
# undo with: php8.3 artisan migrate:rollback --step=2   (each ran as its own batch)
set -euo pipefail
cd "$(dirname "$0")/backend"

REMOTE=codecell@SERVER_IP
APP=/home/codecell/htdocs/shobuj-app

MIGRATIONS=(
  database/migrations/2026_09_22_000001_create_user_follows_table.php
  database/migrations/2026_09_22_000002_create_listing_reviews_table.php
)
# New classes nothing running uses yet — safe to add before migrating.
NEW_FILES=(
  app/Http/Controllers/Api/V1/FollowController.php
  app/Http/Controllers/Api/V1/ListingReviewController.php
  app/Http/Requests/ListingReview/StoreListingReviewRequest.php
  app/Http/Resources/ListingReviewResource.php
  app/Models/ListingReview.php
  app/Policies/ListingReviewPolicy.php
)
# Existing files; checked line-by-line against the server before this was
# written, and they differ only by these features.
CHANGED=(
  app/Enums/NotificationType.php
  app/Http/Controllers/Api/V1/AuthController.php
  app/Http/Controllers/Api/V1/GroupController.php
  app/Http/Controllers/Api/V1/HomeFeedController.php
  app/Http/Controllers/Api/V1/ListingController.php
  app/Http/Controllers/Api/V1/UserController.php
  app/Http/Resources/ListingResource.php
  app/Http/Resources/UserResource.php
  app/Models/Listing.php
  app/Models/User.php
  routes/api.php
)

# -n: don't let ssh read this script's stdin (the confirmation answer).
remote() { ssh -n "$REMOTE" "$@"; }

echo "==> Backing up the server's current copies"
remote "cd $APP && mkdir -p /home/codecell/backups && B=/home/codecell/backups/follows-reviews-\$(date +%Y%m%d-%H%M%S).tar.gz && tar -czf \$B ${CHANGED[*]} && echo \"    \$B\""

echo "==> Uploading the migrations and new classes"
COPYFILE_DISABLE=1 tar --no-xattrs -cf - "${MIGRATIONS[@]}" "${NEW_FILES[@]}" | ssh "$REMOTE" "cd $APP && tar --warning=no-timestamp -xf -"
remote "cd $APP && for f in ${MIGRATIONS[*]} ${NEW_FILES[*]}; do php8.3 -l \$f >/dev/null || { echo \"SYNTAX ERROR in \$f\"; exit 1; }; done && echo '    syntax ok'"

echo "==> Pending migrations (should be ONLY the user_follows and listing_reviews ones)"
remote "cd $APP && php8.3 artisan migrate:status --pending --no-ansi"
read -r -p "Run those migrations on production? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Stopped before migrating. Only unused new files were added."; exit 1; }
for m in "${MIGRATIONS[@]}"; do
  remote "cd $APP && php8.3 artisan migrate --force --path=$m"
done

echo "==> Uploading ${#CHANGED[@]} changed files"
COPYFILE_DISABLE=1 tar --no-xattrs -cf - "${CHANGED[@]}" | ssh "$REMOTE" "cd $APP && tar --warning=no-timestamp -xf -"

echo "==> Syntax check and autoloader (new classes)"
remote "cd $APP && for f in ${CHANGED[*]}; do php8.3 -l \$f >/dev/null || { echo \"SYNTAX ERROR in \$f - restore the backup above\"; exit 1; }; done && echo '    ok'"
remote "cd $APP && php8.3 /usr/local/bin/composer dump-autoload --optimize --no-dev --no-interaction 2>&1 | tail -1"

echo "==> Rebuilding caches and purging Varnish"
remote "cd $APP && php8.3 artisan optimize:clear >/dev/null && php8.3 artisan config:cache >/dev/null && php8.3 artisan route:cache >/dev/null && php8.3 artisan view:cache >/dev/null && php8.3 artisan event:cache >/dev/null && sudo /usr/bin/clpctlWrapper varnish-cache:purge --purge=all 2>&1 | tail -1"
remote "cd $APP && echo \"    follow routes: \$(php8.3 artisan route:list --path=follow --no-ansi | grep -c follow)  review routes: \$(php8.3 artisan route:list --path=reviews --no-ansi | grep -c reviews)  suggested routes: \$(php8.3 artisan route:list --path=suggested --no-ansi | grep -c suggested)\""

echo "==> Smoke test"
for path in /up /privacy /api/v1/config/stripe-key; do
  code="$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' "https://codecell.site$path" || true)"
  echo "    $path -> $code"
  [ "$code" = "200" ] || { echo "Unexpected status for $path - check storage/logs/laravel.log on the server." >&2; exit 1; }
done

echo "Deployed."
