#!/usr/bin/env bash
# One-off deploy of ONLY the chat-reactions change (plus the reply_to_id
# integer cast fix) to production. Backs up every server file it replaces:
#   ssh codecell@SERVER_IP 'cd /home/codecell/htdocs/shobuj-app && tar -xzf <backup path printed below>'
# The migration only creates two new tables; undo with
#   php8.3 artisan migrate:rollback --step=1
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT/backend"

REMOTE=codecell@SERVER_IP
APP=/home/codecell/htdocs/shobuj-app

# routes/api.php is NOT taken from this checkout (it also has undeployed
# follow/review routes): it's the server's own copy plus the 4 reaction
# routes, prepared in .deploy-reactions/. Refuse if the server's copy has
# changed since that was prepared.
ROUTES_PATCHED="$ROOT/.deploy-reactions/routes/api.php"
ROUTES_SERVER_MD5=41797be9aefe8f28e4d730681453b877

NEW_FILES=(
  database/migrations/2026_09_30_000003_create_chat_message_reactions_tables.php
  app/Models/MessageReaction.php
  app/Models/GroupMessageReaction.php
  app/Events/MessageReactionsUpdated.php
  app/Events/GroupMessageReactionsUpdated.php
)
CHANGED=(
  app/Models/Concerns/HasMessageImages.php
  app/Models/Message.php
  app/Models/GroupMessage.php
  app/Http/Controllers/Api/V1/MessageController.php
  app/Http/Controllers/Api/V1/GroupMessageController.php
  app/Http/Resources/MessageResource.php
  app/Http/Resources/GroupMessageResource.php
)
MIGRATION=${NEW_FILES[0]}

# -n: don't let ssh read this script's stdin (the confirmation answer).
remote() { ssh -n "$REMOTE" "$@"; }

echo "==> Checking the server's routes/api.php is unchanged"
actual="$(remote "md5sum $APP/routes/api.php" | cut -d' ' -f1)"
[ "$actual" = "$ROUTES_SERVER_MD5" ] || { echo "routes/api.php on the server changed since this deploy was prepared - stopping." >&2; exit 1; }
echo "    ok"

echo "==> Backing up the server's current copies"
remote "cd $APP && mkdir -p /home/codecell/backups && B=/home/codecell/backups/chat-reactions-\$(date +%Y%m%d-%H%M%S).tar.gz && tar -czf \$B ${CHANGED[*]} routes/api.php && echo \"    \$B\""

# New tables + new classes first: nothing running uses them yet, so this is
# harmless to the live code; the changed code that needs them goes up last.
echo "==> Uploading the migration and new classes"
COPYFILE_DISABLE=1 tar --no-xattrs -cf - "${NEW_FILES[@]}" | ssh "$REMOTE" "cd $APP && tar --warning=no-timestamp -xf -"
remote "cd $APP && for f in ${NEW_FILES[*]}; do php8.3 -l \$f >/dev/null || { echo \"SYNTAX ERROR in \$f\"; exit 1; }; done && echo '    syntax ok'"

echo "==> Pending migrations (should be ONLY 2026_09_30_000003_create_chat_message_reactions_tables)"
remote "cd $APP && php8.3 artisan migrate:status --pending --no-ansi"
read -r -p "Run that migration on production? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Stopped before migrating. Only unused new files were added."; exit 1; }
remote "cd $APP && php8.3 artisan migrate --force --path=$MIGRATION"

echo "==> Uploading ${#CHANGED[@]} changed files + routes/api.php"
COPYFILE_DISABLE=1 tar --no-xattrs -cf - "${CHANGED[@]}" | ssh "$REMOTE" "cd $APP && tar --warning=no-timestamp -xf -"
scp -q "$ROUTES_PATCHED" "$REMOTE:$APP/routes/api.php"

echo "==> Syntax check and autoloader (new classes)"
remote "cd $APP && for f in ${CHANGED[*]} routes/api.php; do php8.3 -l \$f >/dev/null || { echo \"SYNTAX ERROR in \$f - restore the backup above\"; exit 1; }; done && echo '    ok'"
remote "cd $APP && php8.3 /usr/local/bin/composer dump-autoload --optimize --no-dev --no-interaction 2>&1 | tail -1"

echo "==> Rebuilding caches and purging Varnish"
remote "cd $APP && php8.3 artisan optimize:clear >/dev/null && php8.3 artisan config:cache >/dev/null && php8.3 artisan route:cache >/dev/null && php8.3 artisan view:cache >/dev/null && php8.3 artisan event:cache >/dev/null && sudo /usr/bin/clpctlWrapper varnish-cache:purge --purge=all 2>&1 | tail -1"
remote "cd $APP && php8.3 artisan route:list --path=reaction --no-ansi | grep -c reaction | sed 's/^/    reaction routes: /'"

echo "==> Smoke test"
for path in /up /privacy /api/v1/config/stripe-key; do
  code="$(/usr/bin/curl -s -o /dev/null -w '%{http_code}' "https://codecell.site$path" || true)"
  echo "    $path -> $code"
  [ "$code" = "200" ] || { echo "Unexpected status for $path - check storage/logs/laravel.log on the server." >&2; exit 1; }
done

echo "Deployed."
