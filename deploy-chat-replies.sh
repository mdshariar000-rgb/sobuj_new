#!/usr/bin/env bash
# One-off deploy of ONLY the chat-reply change to production.
# Backs up the server copies of the changed files first, so it can be undone:
#   ssh codecell@SERVER_IP 'cd /home/codecell/htdocs/shobuj-app && tar -xzf <backup path printed below>'
# (the new migration adds messages.reply_to_id / group_messages.reply_to_id;
#  roll that back with: php8.3 artisan migrate:rollback --step=1)
set -euo pipefail
cd "$(dirname "$0")/backend"

REMOTE=codecell@SERVER_IP
APP=/home/codecell/htdocs/shobuj-app
CHANGED=(
  app/Models/Concerns/HasMessageImages.php
  app/Models/Message.php
  app/Models/GroupMessage.php
  app/Http/Requests/Message/StoreMessageRequest.php
  app/Http/Requests/GroupMessage/StoreGroupMessageRequest.php
  app/Http/Controllers/Api/V1/MessageController.php
  app/Http/Controllers/Api/V1/GroupMessageController.php
  app/Http/Resources/MessageResource.php
  app/Http/Resources/GroupMessageResource.php
)
MIGRATION=database/migrations/2026_09_30_000002_add_reply_to_id_to_chat_messages.php

# -n: don't let ssh read this script's stdin (it swallowed the "y" last time).
remote() { ssh -n "$REMOTE" "$@"; }

echo "==> Backing up the server's current copies"
remote "cd $APP && mkdir -p /home/codecell/backups && B=/home/codecell/backups/chat-replies-\$(date +%Y%m%d-%H%M%S).tar.gz && tar -czf \$B ${CHANGED[*]} && echo \"    \$B\""

# Migrate BEFORE uploading the code: a new nullable column is harmless to the
# code running now, but the new code writes reply_to_id and would fail
# without it.
echo "==> Uploading the migration"
COPYFILE_DISABLE=1 tar --no-xattrs -cf - "$MIGRATION" | ssh "$REMOTE" "cd $APP && tar --warning=no-timestamp -xf -"
remote "cd $APP && php8.3 -l $MIGRATION >/dev/null && echo '    syntax ok'"

echo "==> Pending migrations (should be ONLY 2026_09_30_000002_add_reply_to_id_to_chat_messages)"
remote "cd $APP && php8.3 artisan migrate:status --pending --no-ansi"
read -r -p "Run that migration on production? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Stopped before migrating. Nothing else changed."; exit 1; }
remote "cd $APP && php8.3 artisan migrate --force --path=$MIGRATION"

echo "==> Uploading ${#CHANGED[@]} code files"
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
