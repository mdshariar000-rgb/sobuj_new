# Agro Hub API Reference

**Base URL:** `https://codecell.site/api/v1`

**Transport:** HTTPS. Request/response bodies are `application/json` unless an endpoint accepts file uploads, in which case it takes `multipart/form-data` (noted per endpoint).

**Authentication:** Bearer token issued by Laravel Sanctum. Obtain one from `POST /auth/register` or `POST /auth/login`, then attach it to every subsequent request:

```
Authorization: Bearer 1|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Accept: application/json
```

Tokens do not expire server-side and are not rotated; a token is revoked only by `POST /auth/logout` (which revokes the token used on that request) or by deleting the underlying `personal_access_tokens` row. A user may hold multiple valid tokens simultaneously (one per signed-in device) — logging in on a new device does not invalidate other sessions.

**Versioning:** All routes are namespaced under `/v1` in the path. There is no header-based content negotiation for version.

---

## Conventions

### Pagination

Every list endpoint marked **Paginated** returns Laravel's standard length-aware paginator envelope, produced by wrapping an Eloquent collection in a `Resource::collection()`:

```json
{
  "data": [ /* array of resource objects */ ],
  "links": {
    "first": "https://codecell.site/api/v1/listings?page=1",
    "last": "https://codecell.site/api/v1/listings?page=4",
    "prev": null,
    "next": "https://codecell.site/api/v1/listings?page=2"
  },
  "meta": {
    "current_page": 1,
    "from": 1,
    "last_page": 4,
    "links": [ /* per-page link objects */ ],
    "path": "https://codecell.site/api/v1/listings",
    "per_page": 20,
    "to": 20,
    "total": 73
  }
}
```

Request a specific page with the query parameter `?page=N`. Page size is a fixed server-side constant per endpoint (listed in each section) — it is **not** client-configurable except where an endpoint explicitly documents a `per_page` parameter.

### Timestamps

All `*_at` fields are ISO 8601 strings, e.g. `"2026-09-19T08:15:30+00:00"`.

### Idempotency

This API has no `Idempotency-Key` header mechanism. A handful of mutating endpoints are naturally idempotent by design (documented per endpoint) — e.g. saving an already-saved listing, or re-marking an already-read notification as read.

### Error shapes

| Status | Meaning | Body |
|---|---|---|
| `400` | Malformed request | `{"message": "..."}` |
| `401` | Missing, invalid, or revoked bearer token | `{"message": "Unauthenticated."}` |
| `403` | Authenticated but forbidden | two distinct shapes — see below |
| `404` | Resource does not exist, or is not visible to the caller | `{"message": "No query results for model [App\\Models\\Listing] 42"}` |
| `422` | Validation failure | `{"message": "The given data was invalid.", "errors": {"field": ["Human-readable reason."]}}` |
| `500` | Unhandled server exception | `{"message": "Server Error"}` in production (`APP_DEBUG=false`) |

**401** is emitted globally for any `api/*` route by a custom `AuthenticationException` renderer (`bootstrap/app.php`) — this guarantees a clean JSON body instead of Laravel's default HTML login-redirect, regardless of the request's `Accept` header.

**403** has two distinct causes and bodies, both possible on almost every authenticated endpoint:

- **Suspended account** — `App\Http\Middleware\EnsureUserIsNotSuspended` (alias `not_suspended`) blocks the request before the controller runs:
  ```json
  { "message": "This account has been suspended." }
  ```
  This middleware wraps every authenticated route **except** `GET /auth/me`, `POST /auth/logout`, `DELETE /auth/me`, `POST /device-tokens`, and `DELETE /device-tokens` — a suspended account can still check its own status, sign out, delete its account, and unregister its device.

- **Authorization policy denial** — Laravel's default `AuthorizationException` message:
  ```json
  { "message": "This action is unauthorized." }
  ```

`422` validation errors follow Laravel's default `ValidationException` shape; the `errors` object maps each invalid field to an array of one or more human-readable messages.

### Admin bypass

Every ownership-gated Policy in this API (`ListingPolicy`, `GroupPolicy`, `PostPolicy`, `CommentPolicy`, `EventPolicy`, `SwapOfferPolicy`, `AppNotificationPolicy`) grants full access to any account with `is_admin = true` via a `before()` hook, letting staff act on any user's content from the same endpoints the mobile app uses. **`AiConversationPolicy` is the sole exception** — it has no admin bypass; an AI conversation is only ever visible to the user who owns it.

### Geolocation & fuzzy locations

Every location-bearing resource (`User`, `Listing`) stores an exact coordinate server-side (`base_location`, **never** returned by any endpoint) and a public-facing `location: {latitude, longitude}` that has been randomly offset by 500–1000 meters (`fuzzy_location`). This is a deliberate privacy measure — the API never exposes a user's or listing's exact handover point. A user can hide even the fuzzy location from other users entirely via their `show_handover_radius` profile flag; when `false`, `location` renders as `null` to anyone but the owner.

---

## Authentication

### `POST /auth/register`

Creates a new account and returns a bearer token. No authentication required.

**Headers**

| Header | Required | Value |
|---|---|---|
| `Content-Type` | Yes | `application/json` |
| `Accept` | Yes | `application/json` |

**Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | Yes | Max 255 chars. |
| `email` | string | Yes | Valid email, max 255 chars, must be unique. |
| `password` | string | Yes | Must satisfy Laravel's default `Password` policy; must be accompanied by `password_confirmation` with an identical value (`confirmed` rule). |
| `password_confirmation` | string | Yes | Must match `password`. |
| `latitude` | number | Yes | Between -90 and 90. Mandatory — every account requires a location to participate in this hyper-local app. |
| `longitude` | number | Yes | Between -180 and 180. |
| `location_label` | string | No | Free-text label, e.g. `"Dhanmondi, Dhaka"`. Max 255 chars. |
| `experience_level` | string | No | One of `beginner`, `intermediate`, `experienced`, `expert`. |
| `growing_setup` | string | No | One of `balcony`, `indoor`, `backyard`, `rooftop`, `community_garden`, `greenhouse`. |
| `device_name` | string | No | Label for the issued token (defaults to `"mobile"`). Max 255 chars. |

```json
{
  "name": "Amina Rahman",
  "email": "amina@example.com",
  "password": "Str0ng!Passw0rd",
  "password_confirmation": "Str0ng!Passw0rd",
  "latitude": 23.7461,
  "longitude": 90.3742,
  "location_label": "Dhanmondi, Dhaka",
  "experience_level": "intermediate",
  "growing_setup": "rooftop",
  "device_name": "Amina's Pixel 8"
}
```

**Response `201 Created`**

```json
{
  "data": {
    "id": 154,
    "name": "Amina Rahman",
    "email": "amina@example.com",
    "phone": null,
    "show_handover_radius": true,
    "is_suspended": false,
    "suspension_reason": null,
    "is_verified": false,
    "username": null,
    "bio": null,
    "avatar_url": null,
    "cover_photo_url": null,
    "location_label": "Dhanmondi, Dhaka",
    "growing_interests": [],
    "experience_level": "intermediate",
    "growing_setup": "rooftop",
    "rating_avg": 0.0,
    "location": { "latitude": 23.7469, "longitude": 90.3751 },
    "created_at": "2026-09-19T08:15:30+00:00"
  },
  "token": "1|xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  "token_type": "Bearer"
}
```

`email`, `phone`, `show_handover_radius`, `is_suspended`, and `suspension_reason` are included here because this response represents the caller's own account (forced via `UserResource::asSelf()`) — they are omitted when any other user's `UserResource` is returned elsewhere in this API.

**Errors**

`422` — e.g. duplicate email:
```json
{
  "message": "The given data was invalid.",
  "errors": { "email": ["The email has already been taken."] }
}
```

---

### `POST /auth/login`

Issues a new bearer token for an existing account. Does **not** revoke tokens already issued to other devices — a user may be signed in on several devices concurrently. No authentication required.

**Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `email` | string | Yes | Valid email. |
| `password` | string | Yes | |
| `device_name` | string | No | Label for the issued token (defaults to `"mobile"`). Max 255 chars. |

```json
{ "email": "amina@example.com", "password": "Str0ng!Passw0rd", "device_name": "Amina's Pixel 8" }
```

**Response `200 OK`** — identical shape to register's `201`, minus `Location: ` semantics (no `Location` header; status is simply `200`).

**Errors**

`422` — wrong email or password (deliberately generic, doesn't reveal which):
```json
{
  "message": "The given data was invalid.",
  "errors": { "email": ["The provided credentials are incorrect."] }
}
```

`403` — correct credentials, but the account is suspended (checked **before** the token is issued — a suspended account's login attempt never receives a working token):
```json
{ "message": "This account has been suspended: Repeated marketplace scam reports." }
```
If no `suspension_reason` was set by the admin, the body is the generic `{"message": "This account has been suspended."}`.

---

### `GET /auth/me`

Returns the authenticated account, including two owner-only counts. Used by the mobile app both to restore a session (validate a stored token) and to detect a suspension applied after the token was issued. **Not** blocked by `not_suspended` — a suspended account must still be able to see its own status.

**Headers:** `Authorization: Bearer <token>` (required).

**Response `200 OK`**

```json
{
  "data": {
    "id": 154,
    "name": "Amina Rahman",
    "email": "amina@example.com",
    "phone": null,
    "show_handover_radius": true,
    "is_suspended": false,
    "suspension_reason": null,
    "is_verified": false,
    "username": "amina_grows",
    "bio": "Rooftop gardener, Dhaka.",
    "avatar_url": "https://codecell.site/storage/avatars/8f3c1e2a-....jpg",
    "cover_photo_url": null,
    "location_label": "Dhanmondi, Dhaka",
    "growing_interests": ["tomatoes", "basil"],
    "experience_level": "intermediate",
    "growing_setup": "rooftop",
    "rating_avg": 4.8,
    "location": { "latitude": 23.7469, "longitude": 90.3751 },
    "posts_count": 12,
    "active_listings_count": 3,
    "followers_count": 41,
    "following_count": 18,
    "created_at": "2026-01-04T10:02:00+00:00"
  }
}
```

`posts_count` and `active_listings_count` are present **only** on this endpoint and `PATCH /auth/me` (both explicitly load these counts) — they are absent from `UserResource` payloads returned elsewhere (e.g. embedded in a listing's `owner`). `followers_count`/`following_count` are present here, on `PATCH /auth/me`, on `GET /users/{user}`, and on the `UserResource` returned by `POST`/`DELETE /users/{user}/follow` — see the Follow Graph section below. `is_following` is present on `GET /users/{user}` and the follow/unfollow responses (never here — following yourself is meaningless).

**Errors:** `401` if the token is missing/invalid.

---

### `PATCH /auth/me`

Partial update of the caller's own profile. Every field is optional (`sometimes`) — send only what changed. Accepts `multipart/form-data` when uploading `avatar`/`cover_photo`, or plain JSON otherwise.

**Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | No | Max 255. |
| `username` | string \| null | No | Max 30, pattern `^[a-zA-Z0-9_]+$`, must be unique (excluding the caller's own current row). |
| `bio` | string \| null | No | Max 300. |
| `phone` | string \| null | No | Max 30. |
| `location_label` | string \| null | No | Max 255. |
| `growing_interests` | string[] \| null | No | Max 10 items, each max 40 chars. |
| `show_handover_radius` | boolean | No | Accepts any of `true`/`false`/`"true"`/`"false"`/`1`/`0`/`"1"`/`"0"` — normalized server-side since multipart form data has no native boolean type. |
| `experience_level` | string \| null | No | `beginner` \| `intermediate` \| `experienced` \| `expert`. |
| `growing_setup` | string \| null | No | `balcony` \| `indoor` \| `backyard` \| `rooftop` \| `community_garden` \| `greenhouse`. |
| `avatar` | file | No | JPEG/PNG/WebP, max 8192 KB. |
| `cover_photo` | file | No | JPEG/PNG/WebP, max 8192 KB. |

**Response `200 OK`** — same shape as `GET /auth/me`, reflecting the new values.

**Errors**

`422` — e.g. taken username:
```json
{ "message": "The given data was invalid.", "errors": { "username": ["The username has already been taken."] } }
```

---

### `POST /auth/logout`

Revokes the Sanctum token used to authenticate this specific request (signs out this device only — other devices' tokens are untouched). Not blocked by `not_suspended`.

**Response `200 OK`**
```json
{ "message": "Logged out." }
```

---

### `DELETE /auth/me`

Permanently deletes the caller's own account and personal data (profile, listings, posts, comments, events, chat messages, uploaded photos, device tokens). Re-authentication is required, so a stolen token alone cannot wipe an account. **Not** blocked by `not_suspended`: a suspended account can still delete itself.

Groups the caller created that still have other members are handed to another member (an existing admin, else the longest-standing member) rather than deleted; a group with no other members is deleted with its creator.

**Request body**: the password, **or** a fresh Google/Apple sign-in for the linked account (for accounts made with Google/Apple, `has_password: false`).

| Field | Type | Required |
|---|---|---|
| `password` | string | Unless `id_token` is sent: the account's current password. |
| `provider` | `google` \| `apple` | With `id_token`. |
| `id_token` | string | A fresh ID token from that provider; its `sub` must match the account's linked ID. Accepted even if the provider has since been switched off in Settings. |
| `nonce` | string | Apple: the raw nonce whose SHA-256 is in the token. |
| `authorization_code` | string | Apple: the one-time code. When the Apple key is set in Settings, the server revokes the Sign in with Apple link. A failed revoke is logged and doesn't block deletion. |

**Response `200 OK`**
```json
{ "message": "Your account has been deleted." }
```

**Errors**

`422` — missing or wrong password, or a token for a different Google/Apple account:
```json
{ "message": "The password is incorrect.", "errors": { "password": ["The password is incorrect."] } }
```

`503` — the deletion failed on the server (or the provider's keys couldn't be fetched); the account is left untouched:
```json
{ "message": "Your account could not be deleted right now. Please try again shortly." }
```

---

## Trust & Safety

User-generated-content moderation tooling (reporting and blocking). Reports land in the admin panel's **Reports** queue; a reported listing is also flagged in the listing-moderation queue.

### `POST /reports`

Reports a piece of content or a user. Idempotent per `(reporter, target)`: re-reporting the same item returns `200` without creating a second report.

**Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `target_type` | string | Yes | `post` \| `comment` \| `listing` \| `event` \| `group` \| `user` \| `group_message` \| `message` (a swap-offer chat message). |
| `target_id` | integer | Yes | Id of the reported row. |
| `reason` | string | Yes | `spam` \| `inappropriate` \| `harassment` \| `misleading` \| `illegal` \| `other`. |
| `details` | string \| null | No | Max 500. |

```json
{ "target_type": "post", "target_id": 3021, "reason": "spam", "details": "Looks like an ad." }
```

**Response `201 Created`** (new report) or **`200 OK`** (already reported)
```json
{ "message": "Thanks — our team will review this report." }
```

**Errors**

`422` — the target doesn't exist, is the caller's own content (or the caller themselves), or a field is invalid:
```json
{ "message": "You cannot report your own content.", "errors": { "target_id": ["You cannot report your own content."] } }
```

---

### `POST /users/{user}/block` · `DELETE /users/{user}/block`

Blocks / unblocks a user. Idempotent. Blocking is **mutual in effect**: each side stops seeing the other's posts, comments, listings, events, group messages, and profile (`GET /users/{user}` and `/users/{user}/listings` return `404`), swap-offer threads between them drop out of both inboxes, neither can make a swap offer to or message the other (`403`), and neither triggers notifications for the other.

**Response `200 OK`**
```json
{ "message": "User blocked." }
```
or
```json
{ "message": "User unblocked." }
```

**Errors:** `422` when blocking yourself — `{"errors": {"user": ["You cannot block yourself."]}}`.

---

### `GET /blocks`

The accounts the caller has blocked, most recently blocked first. **Paginated**, 50/page.

**Response `200 OK`** — paginated `UserResource` collection.

---

## Device Tokens

Registers a device's Firebase Cloud Messaging token so the backend can deliver push notifications for likes, comments, replies, and chat messages. Neither route is blocked by `not_suspended` — a suspended account must still be able to unregister on logout.

### `POST /device-tokens`

Upserts **by `token` alone**, not `(user_id, token)` — if the same physical device token was previously registered under a different account (a shared device, or a re-login as someone else), this reassigns ownership so the old account stops receiving that device's pushes.

**Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `token` | string | Yes | Max 255. The FCM registration token. |
| `platform` | string | No | `android` or `ios`. Defaults to `android`. |
| `device_id` | string | No | Max 255. |
| `app_version` | string | No | Max 32. |

**Response `200 OK`**
```json
{ "message": "Device token registered." }
```

### `DELETE /device-tokens`

Deletes the token row matching **both** the given `token` and the caller's own `user_id` — one account cannot delete another's row even if it somehow obtained the token value.

**Request body**

| Field | Type | Required |
|---|---|---|
| `token` | string | Yes |

**Response `200 OK`**
```json
{ "message": "Device token removed." }
```

---

## Users

### `GET /users/{user}`

A grower's public profile, e.g. reached from "View Seller Profile" on a listing card. Exposes only what `UserResource` already treats as public — never email, phone, or suspension state.

**Path parameters:** `user` (integer, required) — the target user's id.

**Response `200 OK`**: a `UserResource` object (see the shape under `GET /auth/me`), minus the self-only fields `email`, `phone`, `show_handover_radius`, `is_suspended` and `suspension_reason`. It includes:
- `followers_count` and `following_count`
- `is_following`: whether the caller currently follows this user
- `posts_count`: their Home feed posts that haven't been taken down, which is what their profile's Posts tab lists
- `active_listings_count`
- `seller_rating`: the average rating buyers gave their listings, to one decimal place. It's `null` when there are no reviews. Reviews from users the caller has blocked, or been blocked by, are left out.
- `seller_reviews_count`
- `completed_deals_count`: swap offers with status `completed`, whether this user was the seller or the buyer

**Errors:** `404` if no such user, or if either side has blocked the other.

### `GET /users/{user}/listings`

That user's **active** marketplace listings only (`status: active`), newest first. **Paginated**, 20/page.

**Response `200 OK`** — paginated envelope of `ListingResource` objects (see Marketplace section below). `owner` is present on each item (relation is eager-loaded here, unlike `GET /listings`).

---

### `GET /users/{user}/posts`

A profile's posts ("My Posts" / a grower's Posts tab), newest first, paginated. Only the user's posts in groups the viewer can see — active groups that are public or that the viewer belongs to. On your own profile it's every active group you posted in, including posts still awaiting a private group's approval (`approval_status: "pending"`). Each post includes its `group` (for the "in ⟨group⟩" label) and `can_share`. `404` if either user has blocked the other.

---

## Follow Graph

A one-way social signal ("see more from this grower"), separate from group membership (bidirectional, carries a role) and from blocking (mutual, hides content both ways). Following a blocked (or blocking) account is impossible, same 404 as `GET /users/{user}`. Following someone new sends them a `user_followed` notification (see Notifications); re-following an already-followed user never re-notifies them.

### `GET /users/suggested`

Growers to follow during onboarding, up to 20: the nearest ones within 100 km of the caller's registered location first, then the most active growers anywhere. Never the caller, anyone they already follow, anyone blocked either way, or suspended accounts. Not paginated. Each entry is a `UserResource` including `posts_count`.

### `POST /users/{user}/follow` · `DELETE /users/{user}/follow`

Follows / unfollows a user. Idempotent.

**Path parameters:** `user` (integer, required) — the target user's id.

**Response `200 OK`** — a `UserResource` for `{user}` with fresh `followers_count`/`following_count` and `is_following` reflecting the caller's new state.

**Errors:** `422` when following yourself — `{"errors": {"user": ["You cannot follow yourself."]}}`. `404` if no such user, or if either side has blocked the other.

### `GET /users/{user}/followers` · `GET /users/{user}/following`

`{user}`'s followers, or the accounts `{user}` follows, most recently followed first. **Paginated**, 50/page. Any user the caller has blocked (or who has blocked the caller) is excluded from either list, same as the Home Feed.

**Response `200 OK`** — paginated `UserResource` collection.

**Errors:** `404` if no such user, or if the caller and `{user}` have blocked each other.

---

## Marketplace

### `GET /listing-categories`

The full admin-managed category list (used to populate the "create listing" category picker). Not paginated — always a short, admin-curated reference list.

**Response `200 OK`**
```json
{
  "data": [
    { "id": 1, "name": "Seeds & Scions" },
    { "id": 2, "name": "Live Plants & Saplings" },
    { "id": 3, "name": "Organic Fertilizers" },
    { "id": 4, "name": "Farm Tools & Equipment" },
    { "id": 5, "name": "Harvest & Produce" },
    { "id": 6, "name": "Compost & Soils" }
  ]
}
```

`listing_type` on a listing is a free-form string matched against this table's `name` column (`Rule::exists`), not a fixed enum — an admin can add/rename categories at any time from the web panel.

---

### `GET /sowing-guide`

The UK sowing guide behind the app's "What can you grow now?" screen: all 12 months, in order, not paginated. Admins edit each month's two plant lists in the web panel (Content → What Can You Grow); months are never added or removed. The app picks the current month from the phone's date.

**Response `200 OK`**
```json
{
  "data": [
    { "month": 1, "outdoors": ["Garlic", "Broad beans (mild areas)"], "under_cover": ["Onions from seed", "Sweet peas", "Chillies", "Microgreens"] },
    { "month": 2, "outdoors": ["Garlic", "Shallots"], "under_cover": ["Tomatoes"] }
  ]
}
```

Either list can be empty.

---

### `GET /listings/nearby`

Geospatial discovery search — the marketplace's primary browse endpoint. **Paginated**, default 20/page (client-adjustable via `per_page`).

**Query parameters**

| Param | Type | Required | Notes |
|---|---|---|---|
| `latitude` | number | Yes | Between -90 and 90. |
| `longitude` | number | Yes | Between -180 and 180. |
| `radius_km` | number | No | Between 1 and 50. Defaults to 10. |
| `category` | string | No | Must match a `listing_categories.name` row. |
| `transaction_type` | string | No | `swap` \| `free` \| `sell` \| `swap_or_cash` \| `wanted`. |
| `per_page` | integer | No | Between 1 and 50. Defaults to 20. |
| `sort` | string | No | `nearest` (default) or `newest`. |
| `q` | string | No | Max 255. Free-text search against title/variety/looking_for/description. |

**Response `200 OK`** — paginated envelope of `ListingResource` objects. Each item includes `distance_km` (only on this endpoint, and only when the listing's location is visible to the caller — otherwise the key is entirely omitted, not `null`).

---

### `GET /listings/saved`

The caller's bookmarked listings, most-recently-saved first. **Paginated**, 20/page. Excludes logically-deleted listings.

**Response `200 OK`** — paginated `ListingResource` collection; every item has `is_saved: true`.

---

### `GET /listings`

The caller's **own** listings — including reserved/completed/deleted ones (this is a management view, not the discovery feed). **Paginated**, 20/page, newest first.

**Response `200 OK`** — paginated `ListingResource` collection. **`owner` key is absent** on this endpoint (the `user` relation isn't eager-loaded, since it's always the caller).

---

### `POST /listings`

Creates a new marketplace listing. `multipart/form-data` when uploading photos.

**Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `title` | string | Yes | Max 255. Checked against the banned/invasive-species list (see below). |
| `variety` | string \| null | No | Max 255. Also checked against the banned-species list. |
| `description` | string \| null | No | Max 2000. |
| `condition` | string \| null | No | `new_fresh` \| `established_potted` \| `lightly_used` \| `organic_certified`. |
| `listing_type` | string | Yes | Must match a `listing_categories.name` row. |
| `transaction_type` | string | Yes | `swap` \| `free` \| `sell` \| `swap_or_cash` \| `wanted`. |
| `price` | number | Conditional | **Required when `transaction_type` is `sell` or `swap_or_cash`**; otherwise optional. Min 0, max 99999.99. |
| `looking_for` | string \| null | No | Max 1000. |
| `handover_note` | string \| null | No | Max 500. |
| `latitude` | number | No | Between -90 and 90. Required together with `longitude` if either is sent. Defaults to the poster's own account location if omitted. |
| `longitude` | number | No | Between -180 and 180. |
| `photos` | file[] | No | Max 6 files, each JPEG/PNG/WebP, max 8192 KB. |

```json
{
  "title": "Cherry Tomato Seedlings",
  "variety": "Sweet Million",
  "description": "6 healthy seedlings, ~4 weeks old, grown organically.",
  "condition": "established_potted",
  "listing_type": "Live Plants & Saplings",
  "transaction_type": "swap_or_cash",
  "price": 5.00,
  "looking_for": "Basil or mint cuttings",
  "handover_note": "Available evenings after 6pm, Dhanmondi 27"
}
```

**Response `201 Created`** — a `ListingResource` object:
```json
{
  "data": {
    "id": 512,
    "title": "Cherry Tomato Seedlings",
    "variety": "Sweet Million",
    "description": "6 healthy seedlings, ~4 weeks old, grown organically.",
    "condition": "established_potted",
    "condition_label": "Established / Potted",
    "listing_type": "Live Plants & Saplings",
    "transaction_type": "swap_or_cash",
    "price": 5.0,
    "status": "active",
    "looking_for": "Basil or mint cuttings",
    "handover_note": "Available evenings after 6pm, Dhanmondi 27",
    "location": { "latitude": 23.7469, "longitude": 90.3751 },
    "views_count": 0,
    "photos": [],
    "is_saved": false,
    "owner": { "...": "UserResource" },
    "created_at": "2026-09-19T08:20:00+00:00",
    "updated_at": "2026-09-19T08:20:00+00:00"
  }
}
```

**Errors**

`422` — banned species reference:
```json
{
  "message": "The given data was invalid.",
  "errors": { "title": ["The title cannot reference \"Japanese Knotweed\", which is a banned or invasive species."] }
}
```

`422` — no location available at all (neither sent in the request nor on file for the account — practically unreachable since registration requires one, but enforced defensively):
```json
{ "message": "The given data was invalid.", "errors": { "latitude": ["A location is required; none was provided and none is on file for your account."] } }
```

---

### `GET /listings/{listing}`

**Path parameters:** `listing` (integer, required).

Increments `views_count` unless the viewer is the listing's own owner (self-views never count).

**Response `200 OK`**: a `ListingResource` object. It has `is_saved` computed live for the caller, plus `can_review`, which is `true` only when the caller completed a deal (a swap offer with status `completed`) for this listing.

**Errors:** `404` if the listing is `deleted` and the caller isn't its owner (owners may still view their own deleted listings).

**Reviews** (`POST /listings/{listing}/reviews`): a new review needs a completed deal for the listing, and returns `422` (`listing`) otherwise. Editing a review the caller already left is still allowed.

---

### `PATCH /listings/{listing}`

Partial update — every field is `sometimes`. Only the listing's owner (or an admin) may update it. New photos are **appended** to existing ones (not replaced), continuing the `sort_order` sequence.

**Request body** — same fields as `POST /listings` (all optional), plus:

| Field | Type | Required | Notes |
|---|---|---|---|
| `status` | string | No | `active` \| `reserved` \| `completed` \| `deleted`. Settable only via update, not create. No transition restrictions are enforced — any value is accepted from an authorized caller. |

**Response `200 OK`** — updated `ListingResource`.

**Errors:** `403` if the caller doesn't own the listing (and isn't an admin).

---

### `DELETE /listings/{listing}`

Logical delete only — sets `status: deleted`; the row is retained so existing swap-offer/message history referencing it stays intact.

**Response `200 OK`**
```json
{ "message": "Listing deleted." }
```

**Errors:** `403` if the caller doesn't own the listing.

---

### `POST /listings/{listing}/save` · `DELETE /listings/{listing}/save`

Bookmarks / un-bookmarks a listing for the caller. Both are idempotent (saving an already-saved listing, or unsaving an already-unsaved one, is a no-op — no error). No ownership restriction; any authenticated user may save any listing, including their own.

**Response `200 OK`** — the `ListingResource`, with `is_saved` reflecting the new state.

---

### `POST /listings/{listing}/swap-offers`

Opens (or reuses) a negotiation thread on a listing. A new offer sends the listing owner a `swap_offer_received` notification (`data.swap_offer_id`, `data.listing_id`), whose body is the offer's note when one is given.

**Request body**

| Field | Type | Required |
|---|---|---|
| `offer_details` | object \| null | No |
| `offer_details.offered_listing_id` | integer | No — must reference an existing listing. |
| `offer_details.note` | string | No — max 1000. |

```json
{ "offer_details": { "note": "Would you swap for a basil cutting instead?" } }
```

**Response `201 Created`** on a genuinely new offer; **`200 OK`** (same `SwapOfferResource` body, no new row created) if the caller already has a `pending`/`countered`/`accepted` offer on this listing — reopening that existing thread rather than spawning a duplicate.

```json
{
  "data": {
    "id": 88,
    "status": "pending",
    "status_label": "Pending",
    "offer_details": { "note": "Would you swap for a basil cutting instead?" },
    "listing": { "...": "ListingResource" },
    "requester": { "...": "UserResource" },
    "created_at": "2026-09-19T08:25:00+00:00",
    "updated_at": "2026-09-19T08:25:00+00:00"
  }
}
```

**Errors**

`422` — offering on your own listing:
```json
{ "message": "The given data was invalid.", "errors": { "listing_id": ["You cannot make an offer on your own listing."] } }
```

`422` — listing not currently active:
```json
{ "errors": { "listing_id": ["This listing is not currently accepting offers."] } }
```

---

### `GET /swap-offers`

Every swap offer where the caller is either the requester or the listing's owner. **Paginated**, 20/page, newest first.

**Response `200 OK`** — paginated `SwapOfferResource` collection. Each item includes `unread_count` and `last_message` (a compact preview object: `{body, has_image, is_system_event, sender_id, created_at}`, or `null`) — both present **only** on this endpoint.

---

### `GET /swap-offers/{swapOffer}`

**Response `200 OK`** — a `SwapOfferResource`, including `unread_count` but **not** `last_message` (only populated on the index).

**Errors:** `403` if the caller is neither the requester nor the listing's owner.

---

### `PATCH /swap-offers/{swapOffer}/status`

Advances the offer through its state machine. Every transition posts an auto-generated system message into the thread.

**Request body**

| Field | Type | Required |
|---|---|---|
| `status` | string | Yes — `pending` \| `countered` \| `accepted` \| `declined` \| `completed` \| `canceled`. |
| `offer_details` | object \| null | No — only applied when `status` is `countered`. |

**Valid transitions** (enforced by policy, not by the request validator):

| From | Listing owner may set | Requester may set |
|---|---|---|
| `pending` | `accepted`, `declined`, `countered` | `canceled` |
| `countered` | `canceled` | `accepted`, `declined` |
| `accepted` | `completed`, `canceled` | `completed`, `canceled` |
| `declined` / `completed` / `canceled` | — (terminal) | — (terminal) |

**Response `200 OK`**: the updated `SwapOfferResource`.

**The listing follows the deal:**

| Change | Listing status | Other effects |
|---|---|---|
| Offer `accepted` | `active` → `reserved` | Drops out of browsing and the Home feed. |
| Accepted offer `canceled` | `reserved` → `active` | Only if no other offer on the listing is still accepted. |
| Offer `completed` | → `completed` | Every other open offer on the listing (`pending`, `countered` or `accepted`) is set to `declined` with a system message. Each of those requesters gets a `swap_offer_updated` notification. |

On every change, the other party gets a `swap_offer_updated` notification with `data.swap_offer_id` and `data.listing_id`. When the seller marks a deal `completed`, the buyer's notification asks them to leave a review.

**Errors:**
- `403` for any transition not in the table above, e.g. a requester trying to `accept` their own still-`pending` offer.
- `422` (`status`) when accepting an offer on a listing that's already `reserved` for another offer, or is no longer available.

---

### `GET /swap-offers/{swapOffer}/messages`

The offer's chat thread. **Paginated**, 50/page — returns the **most recent** page in chronological order (mimics opening a chat app at the bottom of the conversation). Opening this endpoint marks every unread message from the other party (and every system event) as read.

**Response `200 OK`** — paginated `MessageResource` collection.

```json
{
  "data": [
    {
      "id": 301,
      "swap_offer_id": 88,
      "message_type": "system_event",
      "body": "Amina Rahman made an offer on \"Cherry Tomato Seedlings\".",
      "image_url": null,
      "image_urls": [],
      "sender": null,
      "created_at": "2026-09-19T08:25:00+00:00"
    },
    {
      "id": 302,
      "swap_offer_id": 88,
      "message_type": "text",
      "body": "Sure, that works!",
      "image_url": "https://codecell.site/storage/swap-offers/88/a1.jpg",
      "image_urls": [
        "https://codecell.site/storage/swap-offers/88/a1.jpg",
        "https://codecell.site/storage/swap-offers/88/b2.jpg"
      ],
      "sender": { "...": "UserResource" },
      "created_at": "2026-09-19T08:31:00+00:00"
    }
  ]
}
```

`image_urls` lists every photo on the message, in the order sent (`[]` for text-only). `image_url` is the first photo (or `null`), kept for older app builds that only show one.

Every message also has `reply_to_id` (the message it replies to, or `null`) and `reply_to`, a compact quote of that message: `{ "id", "body", "sender_name", "image_url", "image_count" }`. `reply_to` is `null` when the message isn't a reply, **and** when it is one but the quoted message has since been deleted or (in group chat) is from a user the caller has blocked or been blocked by. In that case the app shows "Original message unavailable".

`reactions` lists emoji reactions grouped by emoji, in the order each was first used: `[{ "emoji": "❤️", "count": 2, "user_ids": [7, 12] }]` (`[]` when none). There's no per-viewer "mine" flag: the app compares `user_ids` with the signed-in user, so the same payload also works over the realtime channel.

**Errors:** `403` if the caller is neither party to the offer.

---

### `POST /swap-offers/{swapOffer}/messages`

Sends a chat message on the thread — works even on a terminal (`declined`/`completed`/`canceled`) offer. `multipart/form-data` for image attachments.

**Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `body` | string | Conditional | Max 2000. Required unless a photo (`images[]` or `image`) is present. |
| `images[]` | file[] | Conditional | Up to 10 photos, each JPEG/PNG/WebP, max 8192 KB. Sent as repeated `images[]` multipart fields. A photo-only message with no caption is valid. |
| `image` | file | No | Legacy single photo (older app builds). Counted together with `images[]` toward the 10-photo limit. |
| `reply_to_id` | integer | No | Makes this a reply. Must be the id of a message in this same thread (`422` otherwise). |

**Response `201 Created`** — the new `MessageResource`. The other party receives a push notification (`swap_message_received`) with preview text `Str::limit(body, 100)`, or `"📷 Photo"` / `"📷 3 photos"` if the message has no caption.

**Errors:** `422` on `images` if more than 10 photos are sent.

---

### `PUT /swap-offers/{swapOffer}/messages/{message}/reaction`
### `DELETE /swap-offers/{swapOffer}/messages/{message}/reaction`

Sets (`PUT`, body `{ "emoji": "👍" }`) or removes (`DELETE`) the caller's reaction on a message in the thread. One reaction per person per message: a `PUT` with a different emoji replaces the old one. Allowed emoji: 👍 ❤️ 😂 😮 😢 🙏.

**Response `200 OK`** — `{ "data": { "message_id": 302, "reactions": [ ... ] } }`, the message's full new `reactions` (same shape as on the message). The other party gets the same payload live as a `message.reacted` event on `private-swap.{swapOfferId}`.

**Errors:** `403` if the caller isn't a party to the offer or there's a block between the two; `404` if the message isn't in this thread; `422` for any other emoji.

---

## Groups

### `GET /group-categories`

Full admin-managed list, not paginated. Shape identical to `GET /listing-categories`.

### `GET /groups/suggested`

Public groups for the onboarding "Join a few groups" step, up to 20, not paginated. Groups the caller is already in come first with `is_member: true` (registration auto-joins their town, interest, growing-setup and experience groups), then the biggest others (`members_count` included).

### `GET /groups`

Active (non-deactivated/non-banned) groups. **Paginated**, 20/page, newest first.

**Query parameters**

| Param | Type | Required | Notes |
|---|---|---|---|
| `category` | string | No | Exact match on `groups.category`. |
| `search` | string | No | `LIKE` match on group name. |

**Response `200 OK`** — paginated `GroupResource` collection.

```json
{
  "data": [
    {
      "id": 12,
      "name": "Dhaka Rooftop Growers",
      "slug": "dhaka-rooftop-growers",
      "description": "A community for balcony and rooftop gardeners in Dhaka.",
      "category": "Urban Farming",
      "visibility": "public",
      "verified": true,
      "cover_image_url": "https://codecell.site/storage/groups/....jpg",
      "avatar_url": "https://codecell.site/storage/groups/....jpg",
      "members_count": 214,
      "posts_count": 89,
      "posts_today_count": 3,
      "creator": { "...": "UserResource" },
      "is_member": true,
      "join_request_pending": false,
      "pending_join_requests_count": 0,
      "pinned_message": "Meetup this Saturday at Ramna Park, 9am!",
      "pinned_by": { "...": "UserResource" },
      "pinned_at": "2026-09-15T06:00:00+00:00",
      "unread_count": 4,
      "last_message": {
        "body": "See everyone Saturday!",
        "has_image": false,
        "sender_id": 88,
        "sender_name": "Karim Hossain",
        "created_at": "2026-09-18T14:02:00+00:00"
      },
      "created_at": "2025-11-02T09:00:00+00:00",
      "updated_at": "2026-09-18T14:02:00+00:00"
    }
  ]
}
```

`my_role` is absent here (only present on endpoints that eager-load the full `members` relation — `show`/`store`/`join`/`leave`, not `index`).

---

### `POST /groups`

Creates a group. Caller becomes its `admin` member automatically. `multipart/form-data` for image uploads.

**Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | Yes | Max 255. |
| `slug` | string | Yes | Max 255, `alpha_dash`, must be unique. |
| `description` | string \| null | No | Max 2000. |
| `category` | string \| null | No | Must match a `group_categories.name` row. |
| `visibility` | string | No | `public` (default) or `private`. |
| `cover_image` | file | No | JPEG/PNG/WebP, max 8192 KB. |
| `avatar` | file | No | JPEG/PNG/WebP, max 8192 KB. |

**Response `201 Created`** — a `GroupResource`, with `my_role: "admin"` and `is_member: true`.

---

### `GET /groups/{group}`

**Response `200 OK`** — a `GroupResource` with the full member roster eager-loaded (so `my_role` is populated).

**Errors:** `403` — `{"message": "This group is no longer available."}` if the group has been deactivated or banned.

---

### `PATCH /groups/{group}`

Only the group's creator or an `admin`-role member (or a site admin) may update it.

**Request body** — same as create, all `sometimes`, plus:

| Field | Type | Required | Notes |
|---|---|---|---|
| `pinned_message` | string \| null | No | Omit the key to leave the current pin untouched. Send `null` or `""` to unpin. Any other string pins it and stamps `pinned_by`/`pinned_at` with the caller. |

**Side effect:** switching `visibility` from `private` to `public` immediately converts every pending join request into a real membership (rather than leaving requesters stuck waiting on a barrier that no longer exists).

**Response `200 OK`** — updated `GroupResource`.

**Errors:** `403` if the caller doesn't manage the group.

---

### `DELETE /groups/{group}`

Hard delete — cascades to the group's posts, memberships, and events at the database level.

**Response `200 OK`**
```json
{ "message": "Group deleted." }
```

---

### `POST /groups/{group}/join`

Joins a public group instantly, or files a join request against a private one.

**Response `200 OK`** — a `GroupResource` (public group, instant join). **`202 Accepted`** for a private group:
```json
{ "message": "Your request to join has been sent to the group admin." }
```

**Errors**

`422` — already a member:
```json
{ "errors": { "group": ["You are already a member of this group."] } }
```

`422` — request already pending:
```json
{ "errors": { "group": ["Your request to join is already pending approval."] } }
```

`403` — `{"message": "This group is no longer available."}` if deactivated/banned.

---

### `DELETE /groups/{group}/join-requests/me`

Withdraws the caller's own still-pending join request.

**Response `200 OK`**
```json
{ "message": "Join request canceled." }
```

**Errors:** `404` if there is no pending request to cancel.

---

### `GET /groups/{group}/join-requests`

The group's pending join-request queue, oldest first — admin/creator only. **Paginated**, 20/page.

**Response `200 OK`**
```json
{
  "data": [
    { "id": 41, "user": { "...": "UserResource" }, "requested_at": "2026-09-17T11:00:00+00:00" }
  ]
}
```

**Errors:** `403` if the caller doesn't manage the group.

---

### `PATCH /groups/{group}/join-requests/{joinRequest}`

Approves or rejects a pending request.

**Request body**

| Field | Type | Required |
|---|---|---|
| `decision` | string | Yes — `approve` or `reject`. |

**Response `200 OK`** — approving deletes the request row and creates a real membership (no "approved" status is ever stored):
```json
{ "message": "Join request approved." }
```
or
```json
{ "message": "Join request rejected." }
```

**Errors:** `403` if the caller doesn't manage the group; `404` if the join request doesn't belong to this group.

---

### `POST /groups/{group}/leave`

**Response `200 OK`**
```json
{ "message": "Left group." }
```

**Errors:** `422` — the creator cannot leave their own group:
```json
{ "errors": { "group": ["The group creator cannot leave their own group."] } }
```

---

### `GET /groups/{group}/members`

The real member roster, admins first, then by join date. **Paginated**, 20/page.

**Response `200 OK`**
```json
{
  "data": [
    {
      "id": 154,
      "name": "Amina Rahman",
      "username": "amina_grows",
      "avatar_url": "https://codecell.site/storage/avatars/....jpg",
      "is_verified": true,
      "experience_level": "intermediate",
      "growing_setup": "rooftop",
      "role": "admin",
      "joined_at": "2025-11-02T09:00:00+00:00"
    }
  ]
}
```

---

### `GET /groups/{group}/messages`

The group's real-time chat. **Paginated**, 50/page, most-recent-first fetched then reversed to chronological order for display. Opening the endpoint advances the caller's own per-member read watermark to the highest message id returned.

**Response `200 OK`**
```json
{
  "data": [
    {
      "id": 900,
      "group_id": 12,
      "body": "See everyone Saturday!",
      "image_url": null,
      "image_urls": [],
      "sender": { "...": "UserResource" },
      "sender_is_admin": false,
      "created_at": "2026-09-18T14:02:00+00:00"
    }
  ]
}
```

**Errors:** `403` if the caller isn't a member of the group.

---

### `POST /groups/{group}/messages`

**Request body** — identical shape to `POST /swap-offers/{swapOffer}/messages` (`body` and/or up to 10 `images[]`, plus the legacy single `image`; at least a body or one photo; optional `reply_to_id`, which must be a message in this group). `image_urls`/`image_url` and `reply_to_id`/`reply_to` in the response work the same way too.

**Response `201 Created`** — the new `GroupMessageResource`. Every other member is notified (`group_message_received`, batched into one multicast push).

**Errors:** `403` if the caller isn't a member.

---

### `PUT /groups/{group}/messages/{groupMessage}/reaction`
### `DELETE /groups/{group}/messages/{groupMessage}/reaction`

Same as the swap-offer reaction endpoints, for group chat; the live event is `message.reacted` on `private-group.{groupId}`. In `GET /groups/{group}/messages`, reactions from users the caller has blocked (or been blocked by) are left out.

**Errors:** `403` if the caller isn't a member; `404` if the message isn't in this group or is from a blocked user; `422` for any other emoji.

---

### `GET /groups/{group}/posts`

The group's discussion-thread posts. **Paginated**, 20/page, newest first.

A non-admin member sees only `approved` posts plus their own pending/rejected ones; the group's admin sees every post regardless of moderation state.

**Response `200 OK`** — paginated `PostResource` collection (shape documented under Community Feed below).

**Errors:** `403` — `{"message": "This group is no longer available."}` if deactivated/banned.

---

## Posts

Posts live in groups only — there is no personal timeline. A group's posts are listed by `GET /groups/{group}/posts`; a person's posts by `GET /users/{user}/posts`.

### `GET /feed/marketplace`

The marketplace listings the app mixes into the Home feed. They're kept separate from `GET /feed`, so the posts' pagination and ordering are unaffected.

**Response `200 OK`**
```json
{
  "data": {
    "location_label": "Leeds",
    "nearby": [ /* ListingResource, up to 10 */ ],
    "from_following": [ /* ListingResource, up to 10 */ ]
  }
}
```

- `nearby`: active listings near the caller's registration location, used for the "Fresh near you" carousel.
  - It includes listings posted in the last 14 days within 40 km. When that finds fewer than 4, it widens to 60 days and 100 km.
  - It's ranked by distance, then how recent the listing is, then a match with the caller's `growing_interests`.
  - It has at most 2 listings per seller.
  - It leaves out the caller's own listings, listings they've already saved, and anything that's also in `from_following`.
  - It's `[]` if the caller has no location.
- `from_following`: active listings from growers the caller follows, posted in the last 14 days at any distance, newest first. The app shows them in the feed as "<name> listed a new item".
- Both lists:
  - leave out blocked users (in either direction), suspended sellers and banned listings
  - include `is_saved`
  - include `distance_km` when the caller has a location and the seller shows their handover radius


### `POST /posts`

Creates a post in a group's discussion thread (the poster must be a member). `multipart/form-data` for image uploads.

**Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `group_id` | integer | Yes | Must reference an existing, active group. Poster must already be a member. |
| `body` | string | Yes | Max 5000. |
| `image` | file | No | JPEG/PNG/WebP, max 8192 KB. |

**Moderation note:** a non-admin member's post into a **private** group starts `approval_status: pending` (invisible to the rest of the group until a group admin approves it). Every other case — a public-group post, or the group's own admin posting — is approved immediately.

**Response `201 Created`** — a `PostResource`, `liked_by_me: false`.

**Errors:** `422` if `group_id` is missing, or the caller isn't a member:
```json
{ "errors": { "group_id": ["You must be a member of this group to post in it."] } }
```

---

### `GET /posts/{post}`

**Response `200 OK`** — a `PostResource` with `comments` (top-level + reply comments, flattened) eager-loaded.

**Errors:** `403` — `{"message": "This action is unauthorized."}` if the post is site-moderated away (`moderation_status != visible`), or is a pending/rejected group post the caller can't see (not its author, not that group's admin).

---

### `PATCH /posts/{post}`

Only the post's own author may edit it — `group_id`, `author`, and moderation/approval state are never editable here.

**Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `body` | string | No | Max 5000. |
| `image` | file | No | New image replaces (and deletes) the old one. |
| `remove_image` | boolean | No | Clears the image without uploading a new one. |

**Response `200 OK`** — updated `PostResource`.

**Errors:** `403` if the caller isn't the post's author.

---

### `DELETE /posts/{post}`

**Response `200 OK`**
```json
{ "message": "Post deleted." }
```

**Errors:** `403` if the caller isn't the post's author (no admin-of-group override for deletion — only the author can delete, staff aside).

---

### `POST /posts/{post}/like` · `DELETE /posts/{post}/like`

Idempotent. Liking sends the author a `post_liked` notification, but only on a genuinely new like — re-liking an already-liked post never re-notifies.

**Response `200 OK`** — updated `PostResource` with `liked_by_me` reflecting the new state.

---

### `POST /posts/{post}/approve` · `POST /posts/{post}/reject`

The post's group admin/creator moderates a pending (or previously rejected) post.

**Response `200 OK`**
```json
{ "message": "Post approved." }
```
or
```json
{ "message": "Post rejected." }
```

**Errors:** `403` if the caller doesn't manage the post's group.

---

### `GET /posts/{post}/comments`

Flattened one-level comment thread (a reply-to-a-reply is stored under the same top-level `parent_id`, not nested further), oldest first. **Paginated**, 30/page.

**Response `200 OK`**
```json
{
  "data": [
    {
      "id": 501,
      "post_id": 3021,
      "parent_id": null,
      "body": "Beautiful! What variety?",
      "author": { "...": "UserResource" },
      "replying_to_name": null,
      "created_at": "2026-09-18T07:10:00+00:00",
      "updated_at": "2026-09-18T07:10:00+00:00"
    },
    {
      "id": 505,
      "post_id": 3021,
      "parent_id": 501,
      "body": "Sweet Million, from a friend's cutting.",
      "author": { "...": "UserResource" },
      "replying_to_name": "Karim Hossain",
      "created_at": "2026-09-18T07:15:00+00:00",
      "updated_at": "2026-09-18T07:15:00+00:00"
    }
  ]
}
```

**Errors:** `403` if the post itself isn't visible to the caller (same rule as `GET /posts/{post}`).

---

### `POST /posts/{post}/comments`

**Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `body` | string | Yes | Max 2000. |
| `reply_to_comment_id` | integer \| null | No | The specific comment being replied to (top-level or a reply). Server flattens it to the thread's top-level `parent_id`. |

**Response `201 Created`** — the new `CommentResource`.

Notification side effects: the post's author is notified (`post_commented`); if this is a reply, the replied-to comment's own author is **additionally** notified (`comment_replied`) — unless that would duplicate the post-author notification just sent, or notify the replier about their own comment.

**Errors:** `422` — replied-to comment not found on this post:
```json
{ "errors": { "reply_to_comment_id": ["That comment could not be found on this post."] } }
```
`403` if the post isn't visible to the caller.

---

### `DELETE /comments/{comment}`

Either the comment's own author, or the author of the post it's on, may delete it.

**Response `200 OK`**
```json
{ "message": "Comment deleted." }
```

**Errors:** `403` if the caller is neither.

---

## Events

### `GET /event-categories`

Full admin-managed list, not paginated.

### `GET /events`

Published, not-yet-expired events, soonest first. **Paginated**, 20/page. "Expired" = the event's `ends_at` (or `starts_at`, if no end time) has already passed — an event already underway keeps showing until it actually ends.

**Query parameters**

| Param | Type | Required | Notes |
|---|---|---|---|
| `month` | string | No | Format `YYYY-MM`. Switches to calendar mode: returns **every** event in that month regardless of expiry (past or future). |
| `category` | string | No | Must match `event_categories.name`. |
| `group_id` | integer | No | Narrows to one group's events. |

**Response `200 OK`** — paginated `EventResource` collection.

```json
{
  "data": [
    {
      "id": 77,
      "group_id": 12,
      "title": "Composting 101 Workshop",
      "description": "Hands-on composting basics for beginners.",
      "format": "in_person",
      "format_label": "In Person",
      "category": "Workshop",
      "cover_image_url": "https://codecell.site/storage/events/....jpg",
      "location": "Ramna Park, Dhaka",
      "starts_at": "2026-09-27T03:00:00+00:00",
      "ends_at": "2026-09-27T05:00:00+00:00",
      "capacity": 30,
      "status": "published",
      "status_label": "Published",
      "attendees_count": 18,
      "is_saved": false,
      "host": { "...": "UserResource" },
      "group": { "...": "GroupResource" },
      "my_rsvp_status": "going",
      "created_at": "2026-09-10T09:00:00+00:00",
      "updated_at": "2026-09-15T09:00:00+00:00"
    }
  ]
}
```

`attendees_preview` (up to 8 `UserResource` objects, newest RSVP first) is present **only** on `GET /events/{event}`, where the full `attendees` relation is eager-loaded — it's absent on `index`/`saved`.

---

### `GET /events/saved`

The caller's bookmarked events, most-recently-saved first. **Paginated**, 20/page. Unlike `index`, this intentionally does **not** filter out expired events — a saved past event is still something the user chose to keep.

**Response `200 OK`** — paginated `EventResource` collection, every item `is_saved: true`.

---

### `POST /events`

**Request body**

| Field | Type | Required | Notes |
|---|---|---|---|
| `group_id` | integer \| null | No | Must reference an existing group. |
| `title` | string | Yes | Max 255. |
| `description` | string \| null | No | Max 5000. |
| `format` | string | Yes | `in_person` \| `online` \| `hybrid`. |
| `category` | string \| null | No | Must match `event_categories.name`. |
| `cover_image` | file | No | JPEG/PNG/WebP, max 8192 KB. |
| `location` | string \| null | No | Max 255. |
| `starts_at` | datetime | Yes | Any parseable date. |
| `ends_at` | datetime \| null | No | Must be after `starts_at`. |
| `capacity` | integer \| null | No | Min 1. |
| `status` | string | No | `draft` (default) \| `published` \| `canceled`. |

**Response `201 Created`** — an `EventResource`.

---

### `GET /events/{event}`

**Response `200 OK`** — an `EventResource` with `attendees_preview` and (when authenticated) `is_saved`/`my_rsvp_status` populated.

---

### `PATCH /events/{event}`

Only the event's host may update it.

**Request body** — same fields as create, all `sometimes`.

**Response `200 OK`** — updated `EventResource`.

**Errors:** `403` if the caller isn't the host.

---

### `DELETE /events/{event}`

**Response `200 OK`**
```json
{ "message": "Event deleted." }
```

**Errors:** `403` if the caller isn't the host.

---

### `POST /events/{event}/rsvp`

Upserts the caller's attendance status (idempotent — re-RSVPing overwrites the existing pivot row rather than erroring).

**Request body**

| Field | Type | Required |
|---|---|---|
| `status` | string | Yes — `going` or `interested`. |

**Response `200 OK`** — updated `EventResource` with `my_rsvp_status` set.

---

### `DELETE /events/{event}/rsvp`

**Response `200 OK`**
```json
{ "message": "RSVP canceled." }
```

---

### `POST /events/{event}/save` · `DELETE /events/{event}/save`

Idempotent bookmark / un-bookmark.

**Response `200 OK`** — updated `EventResource` with `is_saved` reflecting the new state.

---

## Notifications

The in-app notification inbox, backing the bell icon shown on the Home, Events, and Groups tabs. Every mutating action elsewhere in this API (like, comment, reply, swap message, group message, follow) writes a row here and pushes via FCM.

### `GET /notifications`

**Paginated**, 20/page, newest first.

**Response `200 OK`**
```json
{
  "data": [
    {
      "id": 9001,
      "type": "post_liked",
      "title": "Karim Hossain liked your post",
      "body": "My first tomato harvest of the season! 🍅",
      "data": { "post_id": 3021, "group_id": null },
      "actor": { "...": "UserResource" },
      "read_at": null,
      "created_at": "2026-09-19T07:45:00+00:00"
    }
  ],
  "links": { "...": "..." },
  "meta": { "...": "..." }
}
```

`type` is one of: `post_liked`, `post_commented`, `comment_replied`, `swap_message_received`, `group_message_received`, `user_followed`.

---

### `GET /notifications/unread-count`

**Response `200 OK`**
```json
{ "unread_count": 5 }
```

---

### `POST /notifications/read-all`

Marks every one of the caller's unread notifications as read.

**Response `200 OK`**
```json
{ "message": "All notifications marked as read." }
```

---

### `POST /notifications/{notification}/read`

Idempotent — marking an already-read notification read again is a no-op (the timestamp doesn't change).

**Response `200 OK`** — the updated `AppNotificationResource`.

**Errors:** `403` if the notification doesn't belong to the caller; `404` if the id doesn't exist.

---

## October 2026 additions

### Sign-up and profile
- `POST /auth/register` and `PATCH /auth/me` accept `growing_interests` (array of strings). On register each value must be one of: `Learning to garden`, `Buyer`, `Seller`, `Garden Project`, `Community Engagement`, `Sustainability`, `Community Gardening`, `Wildlife & Biodiversity`, `Research & Education` (see `App\Support\Interests`).
- `growing_setup` accepts a new value: `allotment`.
- Registering, or changing `location_label`, `growing_interests`, `growing_setup` or `experience_level`, adds the user to matching automatic groups (see `AutoGroupService`): their town (the last part of `location_label` before the country), each listed interest, "`<Setup>` Growers" and "`<Level>` Growers". These groups have `creator: null` and `auto_type` set (`location`, `interest`, `growing_setup`, `experience_level`).

### `POST /auth/forgot-password` (no auth, 5/min)
Body `{ "email" }`. Emails a 6-digit code valid for 30 minutes. Always returns 200 with the same message, whether or not the account exists. Needs working `MAIL_*` settings.

### `POST /auth/reset-password` (no auth, 10/min)
Body `{ "email", "code", "password", "password_confirmation" }`. 422 on `code` if it's wrong or expired; five wrong tries invalidate the code. On success the password changes and every API token for the account is revoked.

### Groups
- `POST /groups` is now **admin-only** (403 for everyone else).
- `POST /group-requests` — body `{ "name", "description"? }` → 201. Shown to admins on **Moderation → Group Requests**, where *Approve & create group* creates a public group with the requester as its admin.
- Group objects include `auto_type` (null for ordinary groups).

### Events
- Create/update accept `registration_fee` (number ≥ 0, nullable; informational — paid at the event) and `proposed_dates` (array of up to 10 dates). Both are returned on event objects (`registration_fee` as a number or null, `proposed_dates` as ISO-8601 strings).
- `GET /events?for_you=1` — same list, but events in the user's groups or hosted by people they follow come first.
- `GET /events/mine?status=draft` — the caller's own events (any status if omitted), most recently updated first.
- New categories: Open Day, Seed Swap, Plant Fair, Nature Walk, Other.
- `GET /events/{event}/reviews` — newest first, paginated, blocked users hidden.
- `POST /events/{event}/reviews` — body `{ "rating"?: 1–5, "body"?: string }`, at least one required. Published events only (404 for drafts).
- `DELETE /events/{event}/reviews/{review}` — author or admin only.

### Search
- `GET /search?q=` (2–100 chars) → `{ data: { listings, members, groups } }`. Listings match title/variety/description or the seller's location; members match name/username/location; groups match name/description. The term is saved to the user's history (last 20 kept).
- `GET /search/suggest?q=` (1–100 chars) → `{ data: { terms: [{ text, type }], listings, members, groups } }` — live suggestions while typing; **not** saved to history. `terms` (max 6) are the user's matching past searches (`type: "history"`), titles of browsable items (`"item"`, starting-with matches first) and towns from members' addresses (`"place"`), de-duplicated. `listings`/`members`/`groups` are the top 3 of each, same rules as `/search`.
- `GET /search/history` → `{ data: [terms…] }`, newest first. `DELETE /search/history` clears it.
- `GET /feed/marketplace` now also returns `for_you`: up to 20 newest listings matching the user's last 5 searches.

### Event chat
- `GET /events/{event}/chat` → the event's conversation as a group object (`event_id` set). Only the host and attendees whose RSVP is `going` may open it (403 otherwise); drafts 404. It's created on first open and its members are kept in sync: RSVPing `going` adds you, switching to `interested` or cancelling removes you.
- Messages, photos, replies, reactions, read state and live updates use the ordinary group chat endpoints (`/groups/{group}/messages…`) and the `group.{id}` channel.
- Event chats never appear in `GET /groups`, `GET /groups/suggested` or search, and can't be joined with `POST /groups/{group}/join`. Deleting the event deletes its chat.

### Full UK address
- `POST /auth/register` now **requires** `address_line1`, `address_city` and `address_postcode` (a valid UK postcode in any spacing/case — stored tidied, e.g. `LS6 3AA`); `address_line2` and `address_county` are optional. The app still sends `latitude`/`longitude`/`location_label`, now taken from the postcode.
- `PATCH /auth/me` accepts the same `address_*` fields (each required if sent, so it can't be blanked) plus `latitude` + `longitude` together, which move the account's map location.
- `GET /auth/me` (and every other "self" user payload) includes `address: {line1, line2, city, county, postcode}` and `needs_address` (true for older accounts with no postcode — the app asks for it before anything else). Other users never receive `address`; admins see and edit it on the Users page.

### Address suggestions (OpenStreetMap)
No auth — used at sign-up. Free, no key: UK addresses from OpenStreetMap via Photon (`PHOTON_URL`, default the public `https://photon.komoot.io`).
- `GET /addresses/suggest?q=` (3–100 chars, 60/min per IP) → `{ data: [{ id, address, line1, line2, city, county, postcode, latitude, longitude }] }`, up to 6 UK houses/streets. Each suggestion is the whole address — there's no separate "get" call. For a street-only match, a house number at the start of `q` is kept in `line1`. `postcode` can be null. Cached for an hour per term.
- 503 when Photon is unreachable; the app then hides the search box and the address is typed by hand. The app must show "© OpenStreetMap contributors" with the suggestions (ODbL).

### Address from postcode (Ideal Postcodes)
No auth (used at sign-up), 20/min per IP. Royal Mail addresses via Ideal Postcodes; the API key is set on the admin **Settings** page. Each postcode is cached for 24 h.
- `GET /addresses/postcode?postcode=LS6 3AA` (any spacing/case) → `{ data: [{ id, address, line1, line2, city, county, postcode, latitude, longitude }] }`, every address at that postcode. `line2` joins Royal Mail's lines 2–3 and can be null; `city` is title-cased.
- `404` `{"message": "We couldn't find that postcode. Please check it."}` for a postcode that doesn't exist (free at Ideal Postcodes).
- `422` for a malformed postcode (no paid call is made).
- `503` `{"message": "Address lookup is unavailable right now."}` when no key is set, credits have run out, or the service is down. The app then fills the town from postcodes.io and asks for the street.

### Sign in with Google / Apple
- `GET /config/social` (no auth) → `{ data: { google: { enabled, ios_client_id, server_client_id }, apple: { enabled } } }`. These are the switches and Google's public client IDs from the admin **Settings** page (both off by default). The Apple private key is never returned.
- `POST /auth/social` (no auth, 20/min per IP). Body: `provider` (`google`|`apple`), `id_token`, optional `nonce` (Apple, raw), `name`, `device_name`.
  - The token is verified against the provider's published keys (signature, expiry, issuer, audience; Apple nonce).
  - **Existing account** (matching `google_id`/`apple_id`, or a verified email, which gets linked) → `200` with the same shape as `/auth/login`, plus `is_new_user: false`.
  - **New person** → `200 { needs_signup: true, email, name }`. Call again adding `name`, the `address_*` fields, `latitude`, `longitude` (and optionally `location_label`, `experience_level`, `growing_setup`, `growing_interests`, with the same rules as `/auth/register`) → `201` with the user, token and `is_new_user: true`. The account gets `has_password: false` until a password is set with *Forgot password*.
  - `401` invalid, expired or wrong-app token, or the provider is switched off (`"Google sign-in isn't set up yet."`); `403` suspended account; `422` no email from the provider, or validation errors; `503` the provider's keys couldn't be fetched.
- Self user payloads add `has_password` and `signed_in_with` (e.g. `["google"]`).
- `POST /auth/reset-password` now also sets `has_password: true`.

### Share pages (web)
- `GET /l/{id}` and `GET /u/{id}` (HTML, no auth): a listing or profile preview with Open Graph tags and *Get it for iPhone / Android* buttons (links from Settings → App Download Links). Only public fields are shown; a closed listing or suspended account shows a fallback.

## Removed features (October 2026)

The **Agri-AI assistant** with its **Premium subscription**, and the **personal Home timeline** (posts outside groups, post categories, re-sharing posts to the timeline), were removed — code, admin pages and data. So that older app builds show a readable message instead of failing, these endpoints still exist and answer **`410 Gone`** with `{"message": "This feature is no longer available. Please update the app."}`:

`GET /config/stripe-key`, `GET /ai/conversations`, `GET /ai/conversations/{conversation}`, `POST /ai/messages`, `GET /subscriptions/me`, `POST /subscriptions`, `DELETE /subscriptions/me`, `GET /feed`, `GET /post-categories`, `POST /posts/{post}/share`.

Other changes that came with it: `POST /posts` now **requires** `group_id` and no longer takes `category`; `PATCH /posts/{post}` no longer takes `category`; posts no longer carry `category`, `is_share`, `shared_post` or `shares_count`. `can_share` now means "offer Share to other apps" (only approved posts in public groups). `GET /feed/marketplace` (Home's "Picked for you") is unaffected.
