#!/usr/bin/env bash
# One-off deploy of ONLY the multi-photo chat change to production.
# The server copies of the 9 changed files are already backed up at
# /home/codecell/backups/chat-photos-20260930-083513.tar.gz
# (restore: cd /home/codecell/htdocs/shobuj-app && tar -xzf <that file>).
set -euo pipefail
cd "$(dirname "$0")/backend"

REMOTE=codecell@SERVER_IP
APP=/home/codecell/htdocs/shobuj-app
FILES=(
  app/Models/Concerns/HasMessageImages.php
  app/Models/Message.php
  app/Models/GroupMessage.php
  app/Http/Requests/Message/StoreMessageRequest.php
  app/Http/Requests/GroupMessage/StoreGroupMessageRequest.php
  app/Http/Controllers/Api/V1/MessageController.php
  app/Http/Controllers/Api/V1/GroupMessageController.php
  app/Http/Resources/MessageResource.php
  app/Http/Resources/GroupMessageResource.php
  app/Services/AccountDeletionService.php
  database/migrations/2026_09_30_000001_add_image_paths_to_chat_messages.php
)

echo "==> Uploading ${#FILES[@]} files"
COPYFILE_DISABLE=1 tar -cf - "${FILES[@]}" | ssh "$REMOTE" "cd $APP && tar --warning=no-timestamp -xf -"

echo "==> Syntax check on the server"
ssh "$REMOTE" "cd $APP && for f in ${FILES[*]}; do php8.3 -l \$f >/dev/null || { echo \"SYNTAX ERROR in \$f\"; exit 1; }; done && echo ok"

echo "==> Refreshing the autoloader (new HasMessageImages trait)"
ssh "$REMOTE" "cd $APP && php8.3 /usr/local/bin/composer dump-autoload --optimize --no-dev --no-interaction 2>&1 | tail -1"

echo "==> Pending migrations (should be ONLY 2026_09_30_000001_add_image_paths_to_chat_messages)"
ssh "$REMOTE" "cd $APP && php8.3 artisan migrate:status --pending --no-ansi"
read -r -p "Run that migration on production? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || { echo "Stopped before migrating."; exit 1; }
ssh "$REMOTE" "cd $APP && php8.3 artisan migrate --force --path=database/migrations/2026_09_30_000001_add_image_paths_to_chat_messages.php"

echo "==> Rebuilding caches and purging Varnish"
ssh "$REMOTE" "cd $APP && php8.3 artisan optimize:clear >/dev/null && php8.3 artisan config:cache >/dev/null && php8.3 artisan route:cache >/dev/null && php8.3 artisan view:cache >/dev/null && php8.3 artisan event:cache >/dev/null && sudo /usr/bin/clpctlWrapper varnish-cache:purge --purge=all 2>&1 | tail -1"

echo "==> Smoke test"
for path in /up /privacy /api/v1/config/stripe-key; do
  code="$(curl -s -o /dev/null -w '%{http_code}' "https://codecell.site$path" || true)"
  echo "    $path -> $code"
  [ "$code" = "200" ] || { echo "Unexpected status for $path - check storage/logs/laravel.log on the server." >&2; exit 1; }
done

echo "Deployed."
