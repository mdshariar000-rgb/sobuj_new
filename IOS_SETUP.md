# iOS / TestFlight setup checklist

Written on Windows, where iOS can't be built. Everything below is what still has to happen on a Mac. The Android app and the backend are already live; the App Store compliance work (report/block, account deletion, public privacy/terms pages, Agri-AI consent) is done and deployed.

## 1. Mac prerequisites

- [ ] Xcode installed from the App Store and opened once (accept the licence, install the iOS platform/simulator).
- [ ] `sudo gem install cocoapods` (or `brew install cocoapods`).
- [ ] Flutter SDK; `flutter doctor` shows no iOS/Xcode errors.
- [ ] Repo cloned; `cd mobile && flutter pub get`.

## 2. Accounts (only you can do these)

- [ ] Apple Developer Program membership ($99/year).
- [ ] Bundle ID `site.codecell.shobujMobile` registered in Certificates, Identifiers & Profiles with the **Push Notifications** capability. (Kept as-is on purpose: the Android ID `com.greensheal.shobuj` was borrowed from another project's Firebase setup and could clash on Apple's side.)
- [ ] App record created in App Store Connect with that bundle ID.
- [ ] Firebase Console: add an **iOS app** with that bundle ID, download `GoogleService-Info.plist`.
- [ ] Apple Developer: create an **APNs Auth Key** (.p8), upload it in Firebase → Project Settings → Cloud Messaging → Apple app configuration.

## 3. Project changes still needed (Claude can do these on the Mac)

- [ ] Put `GoogleService-Info.plist` in `mobile/ios/Runner/` **and add it to the Runner target** in Xcode (Firebase.initializeApp() takes no arguments, so this file is how iOS finds its config).
- [ ] Add `Runner.entitlements` with `aps-environment` (development for debug, production for release) and link it via `CODE_SIGN_ENTITLEMENTS` in the Xcode project. Xcode → Runner target → Signing & Capabilities → **+ Capability → Push Notifications** does this for you. `UIBackgroundModes: remote-notification` is already in `Info.plist`.
- [ ] `ios/Podfile` doesn't exist yet; `flutter build ios` (or `pod install`) generates it. Deployment target is currently 13.0; raise it to **15.0** if `pod install` complains (recent Firebase SDKs need it).
- [ ] Signing: Xcode → Runner target → Signing & Capabilities → pick your Team, keep "Automatically manage signing".
- [ ] Optional: set `CFBundleDisplayName` in `ios/Runner/Info.plist` (currently "Shobuj Mobile") once the final app name is chosen.
- [ ] Run `flutter analyze` and `flutter test` (all should pass; 208 tests at time of writing).

## 4. Build and upload

```
cd mobile
flutter build ipa --release --dart-define=API_BASE_URL=https://codecell.site/api/v1
```

Then upload `build/ios/ipa/*.ipa` with Xcode Organizer (Distribute App → App Store Connect) or the Transporter app. Apple takes ~10–30 minutes to process it, then it appears under App Store Connect → TestFlight. Internal testers (people on your App Store Connect team) can install immediately; external testers need a short beta review.

The API URL is baked in at build time, exactly like the Android build, so don't forget `--dart-define`.

## 5. Verify on a real iPhone (push can't be tested in the simulator)

- [ ] Log in; a row appears in the production `device_tokens` table.
- [ ] From a second account, like/comment/message the first: a push arrives while the app is backgrounded, and tapping it opens the right screen.
- [ ] Report a post, block a user, delete a throwaway account (Profile → shield icon → Privacy & Safety).
- [ ] Agri-AI shows the consent screen before the first chat.

## 6. Open decisions before App Review

- **Stripe vs Apple In-App Purchase (Guideline 3.1.1).** Apple requires IAP for in-app digital subscriptions. Fastest route for the first release: hide the Agri-AI subscription purchase on iOS. Otherwise integrate IAP (RevenueCat or `in_app_purchase`) and have the backend verify Apple receipts alongside Stripe.
- **Support email:** set it in the admin panel → Settings so `/privacy` and `/terms` show a contact address (App Store Connect also asks for a Support URL and Privacy Policy URL: use `https://codecell.site/privacy`).
- **Reviewer demo account** with sample data, described in the App Review notes.
- **Age rating:** user-generated content with chat usually lands at 12+ or 17+.
- **One app name** everywhere ("Agro Hub" vs "Shobuj Mobile").

## 7. First message to give Claude on the Mac

> Read IOS_SETUP.md. I now have Xcode and Flutter set up. Do section 3 (entitlements, Podfile/deployment target, GoogleService-Info.plist wiring), then build the iOS app and tell me what still needs my Apple/Firebase accounts.
