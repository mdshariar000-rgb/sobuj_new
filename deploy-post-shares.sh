#!/usr/bin/env bash
# Deploys post sharing (POST /posts/{post}/share, shared posts in the feed)
# to production. Backs up every server file it replaces:
#   ssh codecell@SERVER_IP 'cd /home/codecell/htdocs/shobuj-app && tar -xzf <backup path printed below>'
# The migration only adds two columns to posts (is_share, shared_post_id);
# undo with: php8.3 artisan migrate:rollback --step=1
set -euo pipefail
cd "$(dirname "$0")/backend"

REMOTE=codecell@SERVER_IP
APP=/home/codecell/htdocs/shobuj-app

MIGRATION=database/migrations/2026_09_30_000004_add_shared_post_id_to_posts_table.php
CHANGED=(
  app/Models/Post.php
  app/Http/Resources/PostResource.php
  app/Http/Controllers/Api/V1/PostController.php
  app/Http/Controllers/Api/V1/HomeFeedController.php
  app/Enums/NotificationType.php
  routes/api.php
)
# The server's copies of CHANGED when this deploy was prepared (same order);
# each local file differs from them only by the share feature.
EXPECTED_MD5=(
  170d7cd70dd091fe826feb8d1790974c
  95bdf071b80030769a47668fc70af5e7
  431e6a433e63a9306129c04f1389fceb
  f74fdaf0ed38638675de9f69c6b755fb
  264765c9bc2aebf27c661f580f147aef
  9ef8e28bcdebbfe9cc7b80c888a3fba1
)

# -n: don't let ssh read this script's stdin (the confirmation answer).
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
remote "cd $APP && mkdir -p /home/codecell/backups && B=/home/codecell/backups/post-shares-\$(date +%Y%m%d-%H%M%S).tar.gz && tar -czf \$B ${CHANGED[*]} && echo \"    \$B\""

# Two new columns with defaults are harmless to the code running now; the
# new code reads them, so the migration goes first.
echo "==> Uploading the migration"
COPYFILE_DISABLE=1 tar --no-xattrs -cf - "$MIGRATION" | ssh "$REMOTE" "cd $APP && tar --warning=no-timestamp -xf -"
remote "cd $APP && php8.3 -l $MIGRATION >/dev/null && echo '    syntax ok'"

echo "==> Pending migrations (should be ONLY 2026_09_30_000004_add_shared_post_id_to_posts_table)"
remote "cd $APP && php8.3 artisan migrate:status --pending --no-ansi"
read -r -p "Run that migration on production? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Stopped before migrating. Nothing else changed."; exit 1; }
remote "cd $APP && php8.3 artisan migrate --force --path=$MIGRATION"

echo "==> Uploading ${#CHANGED[@]} changed files"
COPYFILE_DISABLE=1 tar --no-xattrs -cf - "${CHANGED[@]}" | ssh "$REMOTE" "cd $APP && tar --warning=no-timestamp -xf -"

echo "==> Syntax check on the server"
remote "cd $APP && for f in ${CHANGED[*]}; do php8.3 -l \$f >/dev/null || { echo \"SYNTAX ERROR in \$f - restore the backup above\"; exit 1; }; done && echo '    ok'"

echo "==> Rebuilding caches and purging Varnish"
remote "cd $APP && php8.3 artisan optimize:clear >/dev/null && php8.3 artisan config:cache >/dev/null && php8.3 artisan route:cache >/dev/null && php8.3 artisan view:cache >/dev/null && php8.3 artisan event:cache >/dev/null && sudo /usr/bin/clpctlWrapper varnish-cache:purge --purge=all 2>&1 | tail -1"
remote "cd $APP && php8.3 artisan route:list --path=share --no-ansi | grep -c share | sed 's/^/    share routes: /'"

echo "==> Smoke test"
for path in /up /privacy /api/v1/config/stripe-key; do
  code="$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' "https://codecell.site$path" || true)"
  echo "    $path -> $code"
  [ "$code" = "200" ] || { echo "Unexpected status for $path - check storage/logs/laravel.log on the server." >&2; exit 1; }
done

echo "Deployed."
