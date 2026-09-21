# Agro Hub

A hyper-local agricultural community app: plant/produce marketplace with swaps, groups, a community feed, events, and a paid AI plant-care assistant. The product is called **Agro Hub**; the repo and folders still say `shobuj` (it began as a plant-swap marketplace, and that marketplace is still fully live inside the app).

- `backend/` — Laravel 11 JSON API (`/api/v1`) + Filament 3 admin panel (`/admin`), Sanctum bearer auth, Reverb WebSockets, Cashier/Stripe, Firebase (FCM) push.
- `mobile/` — Flutter app (Riverpod, Dio). Android ships as a sideloaded APK; iOS is not shipped yet (see `IOS_SETUP.md`).
- Production: https://codecell.site (API at `/api/v1`, admin at `/admin`, public legal pages at `/privacy` and `/terms`).
- Full API reference: `backend/docs/API-REFERENCE.md` (+ PDF). Update it when endpoints change.

## Commands

Backend (run from `backend/`):
- `php artisan test` — feature tests use `RefreshDatabase` against whatever database `.env` points at (MySQL with spatial support; sqlite won't work). **Never point `.env` at production.** Four tests fail on a clean tree for reasons unrelated to features: two "saved … most recent first" ordering tests (same-second timestamps), "group members … admins first", and a `85` vs `85.0` price assertion. Everything else should pass.
- `vendor/bin/pint` — code style.

Mobile (run from `mobile/`):
- `flutter analyze` (3 known style infos), `flutter test` (all pass).
- Release APK: `flutter build apk --release --dart-define=API_BASE_URL=https://codecell.site/api/v1`. The API URL is baked in at build time. Bump `version:` in `pubspec.yaml` first (currently `1.0.0+41`).

## Backend conventions

- Controllers in `app/Http/Controllers/Api/V1`, shaped by `Http/Resources/*` (never return models directly), validated by `Http/Requests/*`, authorized by `Policies/*`. Every policy has a `before()` that lets `is_admin` through; **`AiConversationPolicy` deliberately has no admin bypass.**
- Route structure (`routes/api.php`): everything under `auth:sanctum`; a nested `not_suspended` group wraps all but `GET /auth/me`, `POST /auth/logout`, `DELETE /auth/me` and the device-token routes, so suspended users can still see status, sign out, delete their account and unregister their device.
- Admin-managed taxonomies (`listing_categories`, `group_categories`, `event_categories`, `post_categories`) are validated with `Rule::exists(table, 'name')` — **by name, not foreign key**. `listings.listing_type` is a plain string, not an enum.
- Location privacy: models with `HasFuzzyLocation` store an exact `base_location` (never exposed) and a 500–1000 m-offset `fuzzy_location` (what the API returns as `location`).
- Images go through `ImageService::store()` (re-encoded to JPEG, EXIF/GPS stripped, max 1600px).
- Per-current-user flags on list endpoints (`is_member`, `my_rsvp_status`, `liked_by_me`, `is_saved`) must use a correlated subquery (`withExists`/`addSelect`), not eager-loaded relations. Resources use `whenLoaded()`/`when(array_key_exists(...))`, which **silently omits a key** instead of erroring — a missing field only shows up in the client.
- Blocking is mutual: `User::hiddenUserIds()` / `hasBlockRelationWith()` — apply it to any new list of user-authored content, and to anything that lets one user contact another. Reports use `App\Models\Report` (`ReportTargetType` has the list of reportable things; add new ones there).
- Push/notifications: everything goes through `NotificationService` (writes the inbox row + sends FCM). Sending is **synchronous** — there is no queue worker in production, so don't rely on queued jobs. Chat events use `ShouldBroadcastNow` for the same reason.
- Secrets/config editable without SSH live in the `settings` table via `Setting::get/set` (encrypted). Managed on the admin **Settings** page: Gemini key, Stripe keys/prices, Firebase service-account upload, support email. A saved value beats `.env`. The Firebase credentials file is `storage/app/private/firebase-service-account.json` and must **not** be overridden by a `FIREBASE_CREDENTIALS` env var. Never print or cat credential files.
- The AI assistant (`AgriAssistantService`) calls Google **Gemini**, gated behind an Agri-AI subscription. Subscriptions are Stripe via Cashier with a 7-day trial.

## Admin panel (Filament) gotchas

- Navigation groups are Moderation / Categories / System (`AdminPanelProvider`). **Don't give a `NavigationGroup` an icon** if its items have icons — Filament throws and the whole admin 500s.
- `$this->form->fill([...])` in a Livewire page replaces the *entire* form state; always include every field you want to keep.
- Admin login on production is a normal `is_admin` user.

## Mobile conventions

- All network calls go through `lib/services/api_client.dart`; screens catch `ApiException`. Tests use `test/support/fake_api_client.dart` (override only what a test needs) and `FakeSecureStorageService`.
- State is Riverpod (`lib/providers`). After changing what the server returns for many lists (e.g. blocking), invalidate those providers (`refreshAfterBlockChange` in `lib/widgets/safety_actions.dart`).
- UGC safety UI lives in `lib/widgets/safety_actions.dart` (`showReportSheet`, `confirmAndBlockUser`, `UserSafetyMenuButton`) — reuse it for any new place users can see other users' content. Account deletion and blocked users are under Profile → shield icon → Privacy & Safety.
- Agri-AI requires a per-account consent (`aiConsentProvider`) before the first chat; it names Google Gemini.
- Theme colors are in `lib/theme/app_colors.dart`. Keep the brand name "Agro Hub" in user-facing text.

## Deploying (production)

There is no CI. The backend is deployed by tarball; the server is at `SERVER_IP`, user `codecell` (get the password from the owner — **it is not in this repo; prefer setting up an SSH key**). App root on the server: `/home/codecell/htdocs/shobuj-app`. Use `php8.3` and `php8.3 /usr/local/bin/composer`.

1. Tar `backend/` excluding `vendor`, `.env`, `tests`, `docs`, `node_modules`, and everything under `storage/` and `bootstrap/cache` (production keeps its own `.env` and `vendor`).
2. Copy it to `/home/codecell/tmp/`, extract over the app root with `--strip-components=1`.
3. `composer install --no-dev --optimize-autoloader --no-interaction`.
4. `php8.3 artisan migrate:status` — confirm **only the migrations you expect** are pending — then `php8.3 artisan migrate --force`.
5. `optimize:clear`, then `config:cache`, `route:cache`, `view:cache`, `event:cache`.
6. Purge Varnish: `sudo /usr/bin/clpctlWrapper varnish-cache:purge --purge=all`.
7. Smoke test against `https://codecell.site/api/v1` with a throwaway user, then delete that user (`DELETE /auth/me`).

The APK is published by copying it to `storage/app/public/downloads/agrohub-<8 random digits>.apk` on the server, deleting the previous file, and checking the served size matches: `https://codecell.site/storage/downloads/<name>.apk`.

Do the backend deploy **before** shipping an app build that calls new endpoints; an older app keeps working against a newer backend.

## Status / open work

- App Store readiness (report/block, account deletion, privacy/terms pages, AI consent) is built and live. What remains is in `IOS_SETUP.md`: Apple/Firebase accounts, push entitlements, and the Stripe-vs-Apple-IAP decision.
- No rate limiting exists on any API route yet, and push sending is synchronous (no queue worker) — both are scaling limits to fix before heavy traffic.
