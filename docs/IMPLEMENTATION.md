# Implementation details: October 2026 update

What was built, how each part behaves, and what's left. Setup steps are in [SETUP-GUIDE.md](SETUP-GUIDE.md); how the pieces connect is in [ARCHITECTURE.md](ARCHITECTURE.md).

**Status (12 Oct 2026)**
- **Server:** deployed to https://codecell.site.
- **App:** the changes reach users in **app build 47**, which isn't released yet.

---

## 1. Client feedback: inside the app

| # | Request | What changed |
|---|---|---|
| 8 | Slogan under "Good morning…" | Home shows **"Grow. Share. Sustain."** instead of grower type and town. |
| 9 | My Listings items not accessible | **Bug fixed:** the *Manage* button broke the row layout, so the whole My Listings tab was blank. Rows now show, and tapping one opens the listing. |
| 11 | Sent messages showed twice | The server's real-time copy of your own message now replaces the "Sending…" bubble, so each message appears once. Applies to marketplace, group and event chats. |
| 12 | End time for events | The create/edit event form has **End Time**, required to publish (drafts can leave it empty). An end time at or before the start counts as the next day. The event page shows "10:00 AM – 12:00 PM". |
| 13 | Edit my event | Hosts see an **Edit** (✏️) button on their event. Editing a live event shows **Save Changes**, keeps the cover photo, and refreshes the event and lists. Also fixed: reopening a draft no longer shifts its time by an hour. |
| 14, 16 | Share links | Sharing a listing or profile now includes a link (`/l/{id}`, `/u/{id}`). It opens a Shobuj page with a preview and app download buttons. It never shows location or contact details; sold listings and suspended accounts show "no longer available". |
| 15 | Category names | **"Seeds & Scions" → "Seed"** and **"Live Plants & Saplings" → "Live plants"**, with existing listings moved across. Renaming a category in the admin panel now moves its listings too. |
| – | Branding | Remaining "Agro Hub" texts in the app changed to "Shobuj". |
| – | Admin: Subscriptions page | Removed. It was a leftover file still on the server. |

Item 10 (admin access to groups and requests) needed no code: the admin panel already has **Groups** and **Group Requests**.

## 2. Address from postcode

At sign-up and in *Profile → Your address*:

1. The user types the **postcode** and taps **Find address**.
2. The app lists every address at that postcode (Royal Mail data from Ideal Postcodes), and the user taps theirs.
3. Line 1, line 2, town, county and postcode fill in, shown as a card with **Change**.
4. **"My address isn't listed"** opens the fields to type the address, with the town already filled from the postcode.
5. An unknown postcode shows *"We couldn't find that postcode."*

**When there's no Ideal Postcodes key, credits run out, or the service is down:** the server answers "unavailable". The app then fills the town and county from the free postcodes.io service and asks for the house number and street, so sign-up never breaks.

**Cost control:**
- Each postcode result is cached on the server for 24 hours.
- Malformed postcodes are rejected before any paid call.
- The endpoint is limited to 20 requests per minute per IP.

The old "start typing your address" box was removed from the app. Its server endpoint (`/addresses/suggest`) stays for older app builds.

## 3. Continue with Google / Continue with Apple

### Signing in

1. The user taps **Continue with Google** (Android and iPhone) or **Continue with Apple** (iPhone only, using Apple's official button).
2. The phone shows Google's or Apple's own sign-in sheet and returns a signed **ID token**.
3. The app sends the token to the server (`POST /auth/social`). The server checks it (see [ARCHITECTURE.md § Security](ARCHITECTURE.md#security)) and then:
   - **Known account** (same Google/Apple ID): signs in.
   - **Same verified email as an existing account:** links Google/Apple to that account and signs in.
   - **New person:** answers `needs_signup` with their email and name.
4. For a new person the app shows **Finish signing up**: name (pre-filled; Apple only shares it on the first sign-in), the postcode address step, and terms. The app then calls `/auth/social` again with the address, the account is created, and onboarding starts, the same as email sign-up.

### Account rules

- **Password:** accounts created this way have no password (`has_password = false`). They can set one at any time with **Forgot password?**, which also lets them log in with email.
- **Deleting the account:** since there's no password, the user confirms by signing in with Google/Apple again (App Store rule 5.1.1(v)).
  - For Apple, the app also sends Apple's one-time code. The server uses the Apple key from Settings to **revoke** the Apple link, as Apple requires.
  - A failed revocation is logged and never blocks the deletion.
  - Deletion keeps working even if that provider is later switched off in Settings.
- **Suspended accounts** can't sign in this way either.
- **Apple "Hide My Email"** addresses (`…@privaterelay.appleid.com`) are accepted as the account email.

### Settings from the admin panel

- **What's in the panel:** both providers are **off by default**. The switches and client IDs are in *Settings → Social Sign-in*.
- **What the app reads:** it gets the on/off state and Google's public client IDs from `GET /config/social` when it opens. So turning a provider on or off, or changing the IDs, needs **no new app build**.
- **The one exception is Google on iPhone:** Google's iOS library needs the reversed iOS client ID registered in the app's `Info.plist` URL schemes, and crashes without it. The app checks this through a small native channel and **only shows the Google button on iPhone when it's registered**, so adding the iOS client ID is a one-time app update.
- **Apple in release builds:** the Sign in with Apple entitlement is currently in **debug builds only** (`ios/Runner/RunnerDebug.entitlements`). It moves into the release build once the client enables the capability and regenerates the App Store profile. Adding it earlier would break App Store signing.

## 4. Email (SMTP) from the admin panel

*Settings → Email (SMTP)* has host, port, security (STARTTLS/SSL), username, password, from address and from name, plus a **Send test email** button.

- **When there's no host:** the server's `.env` mail settings are used.
- **When saved settings apply:** only when an email is actually being sent, so other requests aren't slowed down.
- **The password:** never shown back in the page; a blank field keeps it.

## 5. Other admin panel additions

- **App Download Links:** the buttons on share pages; hidden until set.
- **Address Lookup (Ideal Postcodes):** the API key and a status line.

## 6. Deploy script

`./deploy.sh` now lists any files on the server that aren't in the deploy. Deploys copy over old files and never delete them, and a leftover admin page file is what kept "Subscriptions" in the menu. The script only reports these files; nothing is deleted automatically.

## 7. Tests

| Suite | Result |
|---|---|
| Server (`php artisan test`) | 358 pass. 8 fail, and all 8 also failed before this update (date-ordering, number-format and local-database quirks unrelated to these features). |
| App (`flutter test`) | 313 pass. |
| On the simulator | Changed screens checked with screenshots. The real Sign in with Apple sheet opens. The iPhone Google check works. |

New test files:
- **Server:** `SocialLoginTest`, `PostcodeAddressLookupTest`, `SharePageTest`, `ListingCategoryRenameTest`, plus additions to `ManageSettingsTest`.
- **App:** `social_sign_in_test.dart`, `chat_echo_test.dart`, `app_config_test.dart`, plus additions to the profile, event and address tests.

## 8. Still to do

| Item | Who | Notes |
|---|---|---|
| Google client IDs | Owner | [SETUP-GUIDE §3](SETUP-GUIDE.md#3-continue-with-google). Send the iOS client ID to the developer. |
| Apple capability, profile and key | Owner (Apple account holder) | [SETUP-GUIDE §4](SETUP-GUIDE.md#4-continue-with-apple) |
| Ideal Postcodes key | Owner | [SETUP-GUIDE §1](SETUP-GUIDE.md#1-address-from-postcode-ideal-postcodes) |
| App build 47 (iOS and Android) | Developer | Ships everything above; include the Google iOS URL scheme and the Apple release entitlement if ready. |
| Removed-features database clean-up | Developer + owner approval | The pending `2026_10_09` migration removes old Agri-AI/Stripe data. It waits on two **test-mode** Stripe subscriptions; a production backup is taken first. |
| Leftover files on the server | Developer | 25 unused files from removed features, including a *Post Categories* admin page. Listed by `deploy.sh`. |
| Forgot-password email wording | Developer | Subject and body still say "Agro Hub". Setting the SMTP **From name** to "Shobuj" fixes only the sender name. |
| Sign-up feedback items | Developer | Login wording ("Welcome back"), Face ID-only quick login, privacy policy (after the domain), Shobuj domain. |
