# Shobuj setup guide

This guide turns on the features that need your own accounts with outside services. Everything is entered in the **admin panel**, so no programming is needed, and you can change it again at any time.

**Admin panel:** https://codecell.site/admin → sign in → **Settings** (left menu, under *System*).

Every section on the Settings page has a **Current status** line that tells you whether it's working. After changing anything, press **Save** at the bottom of the page.

| # | Feature | What you need | Cost | Time |
|---|---|---|---|---|
| 1 | [Address from postcode](#1-address-from-postcode-ideal-postcodes) | Ideal Postcodes account | About 3–4.5p per lookup | 10 min |
| 2 | [Email sending](#2-email-sending-smtp) | A Gmail (or other) mailbox | Free | 10 min |
| 3 | [Continue with Google](#3-continue-with-google) | Google / Firebase console | Free | 30 min |
| 4 | [Continue with Apple](#4-continue-with-apple) | Apple Developer account | Free (part of your membership) | 30 min |
| 5 | [Share-link download buttons](#5-share-link-download-buttons) | App Store link, Android link | Free | 2 min |

> **Keep secrets safe.** API keys, passwords and the Apple `.p8` key are stored encrypted, and the admin panel never shows them again after saving. Don't email them around; paste them straight into the admin panel. To replace one, paste the new value. To keep the current one, leave the field blank.

---

## 1. Address from postcode (Ideal Postcodes)

**What users see:** at sign-up and in *Profile → Your address*, they type only their postcode, tap **Find address**, and pick their address from Royal Mail's list. The street, town and county fill in by themselves.

**Until this is set up:** the app still works. It fills in the town from the postcode and asks the user to type their house number and street.

### Steps

1. Go to **https://ideal-postcodes.co.uk** and create an account **in the business's name**. You pay for this.
2. Buy credits. The smallest pack (about £9 for 200 lookups) is enough to start. Credits last 12 months.
   - One lookup = one postcode search. It returns every address at that postcode.
   - Each postcode is remembered for a day, so the same postcode isn't paid for twice.
   - A postcode that doesn't exist costs nothing.
3. In the Ideal Postcodes dashboard, open **API keys** and copy your key. It starts with `ak_`.
4. In the admin panel: **Settings → Address Lookup (Ideal Postcodes)** → paste the key into **API key** → **Save**.
5. Check **Current status** shows ✅ **Configured**.

**Tip:** if Ideal Postcodes offers a low-balance email alert, turn it on. If credits run out, the app quietly falls back to typing the street by hand.

---

## 2. Email sending (SMTP)

**What it's used for:** password-reset codes and other emails from the app.

**Until this is set up:** the server keeps using the email settings it was installed with.

### Using Gmail

Gmail needs an **App Password**. It won't accept your normal Gmail password.

1. Sign in to the Gmail account the emails should come from.
2. Turn on **2-Step Verification**: https://myaccount.google.com/security
3. Create an App Password at https://myaccount.google.com/apppasswords. Name it "Shobuj" and copy the 16-character password.
4. In the admin panel: **Settings → Email (SMTP)**, fill in:

   | Field | Value |
   |---|---|
   | SMTP host | `smtp.gmail.com` |
   | Port | `587` |
   | Security | STARTTLS (usually port 587) |
   | Username | your full Gmail address |
   | Password | the 16-character App Password |
   | From address | the same Gmail address |
   | From name | `Shobuj` |

5. Press **Save**.
6. Press **Send test email** (top right of the Settings page), enter your own address and check the inbox, including spam.

### Using another email provider

Use the SMTP details your provider gives you. Port `587` uses STARTTLS; port `465` uses SSL.

**To go back to the original settings:** clear the **SMTP host** field and **Save**.

---

## 3. Continue with Google

**What users see:** a **Continue with Google** button on the Log In and Create Account screens.
- People who already have an account are signed straight in.
- New people are asked only for their postcode address, then their account is created.

Google sign-in uses the existing Firebase project for the app, **mighty-rider**.

### Step A: turn on Google sign-in in Firebase

1. Open https://console.firebase.google.com → project **mighty-rider**.
2. **Build → Authentication → Sign-in method → Add new provider → Google**.
3. Switch it on, choose a support email, and **Save**. This creates a **Web client** automatically.

### Step B: set the consent screen

1. Open https://console.cloud.google.com → choose project **mighty-rider**.
2. **APIs & Services → OAuth consent screen**.
3. Set the app name to **Shobuj**, add the support email and logo, and fill in the privacy-policy link (https://codecell.site/privacy for now).
4. Set the publishing status to **In production**, so anyone can sign in, not just test users.

### Step C: create the client IDs

Still in **APIs & Services → Credentials**:

1. **Web client:** find **"Web client (auto created by Google Service)"** and copy its **Client ID**.
2. **iOS client:** **Create credentials → OAuth client ID → iOS**.
   - Bundle ID: `com.greenshelter.shobuj`
   - Copy the **Client ID** it shows.
3. **Android client:** **Create credentials → OAuth client ID → Android**.
   - Package name: `com.greensheal.shobuj`
   - SHA-1 certificate fingerprint: `0F:1E:C8:9F:C9:C5:B4:73:CA:20:5A:A4:DF:0B:36:DF:BF:F8:A1:41`
   - Nothing to copy from this one; it only has to exist.

   > If the Android app is later signed with a new upload key (needed for the Play Store), add that key's SHA-1 here too. If Google Play App Signing is used, also add the SHA-1 Play shows.

### Step D: put them in the admin panel

**Settings → Social Sign-in: Google**:

| Field | Value |
|---|---|
| Allow "Continue with Google" | On |
| iOS client ID | from Step C.2 |
| Web client ID (used by Android) | from Step C.1 |

**Save**, and check the status shows ✅.

### Step E: send the iOS client ID to your developer

iPhones need the iOS client ID built into the app once. Your developer adds it in the next app update, and until then the Google button only appears on Android. After that, everything can be changed from the admin panel without new app builds.

---

## 4. Continue with Apple

**What users see:** Apple's black **Continue with Apple** button on iPhone (Apple only allows it there). It works the same way as Google.

> Apple requires apps that offer Google sign-in on iPhone to offer Sign in with Apple too, so set up both.

These steps need the **Account Holder** of the Apple Developer account (Team ID `XCGZVG9PT7`).

### Step A: enable it for the app

1. Open https://developer.apple.com/account → **Certificates, IDs & Profiles → Identifiers**.
2. Open **com.greenshelter.shobuj**.
3. Tick **Sign In with Apple** (keep "Enable as a primary App ID") → **Save** → **Confirm**.

> **Push notifications:** this is a good moment to also tick **Push Notifications** on the same page. That's still needed for app notifications on iPhone, and doing both now means the profile below only needs regenerating once.

### Step B: regenerate the App Store profile

1. **Profiles** → open **Shobuj App Store** → **Edit** → **Save** (or **Generate**).
2. Tell your developer it's done. They download it and turn Apple sign-in on in the next App Store build.

> Don't switch Apple on in the admin panel (Step D) until that new app build is live. Older builds simply don't show the button.

### Step C: create a Sign in with Apple key

Apple needs this key so that when someone deletes their Shobuj account, the link to their Apple ID is removed too. Apple requires that.

1. **Keys → +** (Create a key).
2. Name it `Shobuj Sign in with Apple` and tick **Sign in with Apple** → **Configure** → primary App ID **com.greenshelter.shobuj** → **Save** → **Continue** → **Register**.
3. **Download** the `.p8` file. Apple only lets you download it **once**, so keep a safe copy.
4. Note the **Key ID** shown on the page (10 characters).

### Step D: put it in the admin panel

**Settings → Social Sign-in: Apple**:

| Field | Value |
|---|---|
| Allow "Continue with Apple" (iPhone) | On (after the new app build is live) |
| App bundle ID / Services ID | `com.greenshelter.shobuj` (or leave blank, which means the same) |
| Team ID | `XCGZVG9PT7` |
| Key ID | from Step C.4 |
| Private key (.p8 file contents) | open the `.p8` file in a text editor and paste **everything**, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |

**Save**, and check the status shows ✅ *"Continue with Apple" is on, and deleted accounts are unlinked from Apple.*

---

## 5. Share-link download buttons

When someone shares a listing or profile from the app, the link opens a Shobuj page with **Get it for iPhone** and **Get it for Android** buttons. Each button only shows once its link is set.

**Settings → App Download Links**:

| Field | Value |
|---|---|
| iPhone (App Store) link | `https://apps.apple.com/app/id6818218536` (works once the app is publicly released) |
| Android link | the Play Store link, or a direct APK download link until it's on the Play Store |

While you're in Settings, also check **Support Contact → Support email**. It's shown on the public Privacy Policy and Terms pages, and the App Store requires it.

---

## Troubleshooting

| Problem | What to check |
|---|---|
| Postcode lookup still asks for the street | **Address Lookup** status: is the key saved? Does the Ideal Postcodes dashboard show credits left? |
| "We couldn't find that postcode" | The postcode really doesn't exist, or has a typo. These lookups are free. |
| Test email fails | The error message is shown on screen. For Gmail: is 2-Step Verification on, and are you using the **App Password**? Is the port 587 with STARTTLS? |
| No Google button on Android | Is **Allow "Continue with Google"** on, and the **Web client ID** filled in? Does the Android OAuth client exist with the SHA-1 above? |
| No Google button on iPhone | Expected until the app update with the iOS client ID is installed (Section 3, Step E). |
| Google says "access blocked" or only testers can sign in | The OAuth consent screen is still in **Testing**. Publish it (Section 3, Step B). |
| No Apple button | Only on iPhone, and only when **Allow "Continue with Apple"** is on. |
| Apple sign-in fails on iPhone | Sign In with Apple must be ticked on the App ID, and the app build must come from the regenerated profile (Section 4, Steps A–B). |
| "Sign-in timed out" on Finish signing up | Google/Apple sign-ins only last a few minutes. Go back and tap Continue with Google/Apple again. |
| Apple status shows ⚠️ | The Team ID, Key ID or `.p8` key is missing (Section 4, Step C). |

**To turn anything off:** switch its toggle off (or clear its key) and **Save**. The server stops accepting it straight away, and the buttons disappear the next time the app is opened. Nobody loses their account. People who signed up with Google or Apple can always delete their account.
