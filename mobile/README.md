# Widgetry Academy app

The Android and iOS app for widgetryacademy.in. It covers:

- **Jobs:** Flutter, Android and iOS jobs with search, filters, saving and reporting. Apply opens the employer's own careers page.
- **Profile and resume:** a Talent Network profile with a profile score and photo, plus an ATS-friendly PDF resume (Modern, Classic or Compact) to share or print.
- **Courses:** the course list, batch details and registration (it uses the same Firestore format as the website).
- **Guides:** the blog, read from `blog/feed.json`.
- **Push notifications:** new jobs by category, academy news, and personal alerts such as "your job is live" or "you're verified".

Package / bundle ID: `in.widgetryacademy.app` · Flutter 3.44 or newer · Dart 3.12 or newer

**Publishing on Google Play:** see [RELEASE.md](RELEASE.md).

---

## 1. First-time setup

Run these from the `mobile/` folder.

```bash
# 1. Generate the android/ and ios/ folders (lib/, test/ and pubspec.yaml are kept)
flutter create --org in.widgetryacademy --project-name widgetry_academy --platforms android,ios .

# 2. Packages
flutter pub get
#    If pub reports a version conflict with your Flutter version:
#    flutter pub upgrade --major-versions

# 3. Generate code (dependency injection, JSON models)
dart run build_runner build --delete-conflicting-outputs

# 4. Connect Firebase (the same project as the website)
dart pub global activate flutterfire_cli
flutterfire configure --project=flutter-in-10-days --platforms=android,ios \
  --android-package-name=in.widgetryacademy.app --ios-bundle-id=in.widgetryacademy.app
#    This overwrites lib/firebase_options.dart and adds google-services.json / GoogleService-Info.plist.
```

`flutter create` names the app `in.widgetryacademy.widgetry_academy`. Change it to **`in.widgetryacademy.app`**:

- **Android:** in `android/app/build.gradle(.kts)`, set `namespace` and `applicationId` to `in.widgetryacademy.app`, and set `minSdk = 23`. Move `MainActivity.kt` to `android/app/src/main/kotlin/in/widgetryacademy/app/`, change its `package` line to match, and delete the old folder.
- **iOS:** in Xcode, open `ios/Runner.xcworkspace`, go to Runner → Signing & Capabilities, and set the Bundle Identifier to `in.widgetryacademy.app`. Set the iOS deployment target to **13.0** or higher, both in Xcode and in `ios/Podfile` with `platform :ios, '13.0'`.

## 2. Platform settings

### Android: `android/app/src/main/AndroidManifest.xml`

Add these inside `<manifest>`, above `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<queries>
  <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
  <intent><action android:name="android.intent.action.SENDTO"/><data android:scheme="mailto"/></intent>
  <intent><action android:name="android.support.customtabs.action.CustomTabsService"/></intent>
</queries>
```

Set the label inside `<application>`: `android:label="Widgetry"`.

### iOS: `ios/Runner/Info.plist`

```xml
<key>CFBundleDisplayName</key><string>Widgetry</string>
<key>NSPhotoLibraryUsageDescription</key><string>Choose a profile photo for your Widgetry profile and resume.</string>
<key>NSCameraUsageDescription</key><string>Take a profile photo for your Widgetry profile and resume.</string>
```

For Google sign-in, add a URL type in Xcode (Runner → Info → URL Types). Set its URL scheme to the **Encoded App ID** shown in Firebase → Project settings → your iOS app. It looks like `app-1-123456789-ios-abc123`.

### Google sign-in (Android)

Get the SHA fingerprints and add both SHA-1 and SHA-256 in Firebase → Project settings → Android app → Add fingerprint:

```bash
cd android && ./gradlew signingReport
```

Add the release key's fingerprints too, and after Play Store upload add the **Play App Signing** key from Play Console → Setup → App signing. Then download `google-services.json` again, or run `flutterfire configure` again.

### Push notifications

- **Android:** works once `google-services.json` is in place.
- **iOS:**
  1. In Xcode, add the **Push Notifications** capability and **Background Modes → Remote notifications**.
  2. In the Apple Developer portal, create an **APNs key** (.p8).
  3. Upload the key in Firebase → Project settings → Cloud Messaging → Apple app configuration.
- **Server:** the Jobs API sends the notifications. In Railway → service → Variables, add `FIREBASE_SERVICE_ACCOUNT` and paste the whole JSON key from Firebase → Project settings → Service accounts → Generate new private key. Without it the server only logs what it would have sent.
- **Admin:** to send an announcement, go to widgetryacademy.in/admin.html → **App notification**.

| Topic | Who gets it | Sent when |
|---|---|---|
| `all` | everyone | announcements to "all" |
| `academy` | on by default, can be switched off in Settings | batch and course news |
| `jobs-flutter`, `jobs-android`, `jobs-ios` | Flutter on by default; others switched on in Settings | a job is approved, or jobs are bulk-imported |
| personal (device token) | the signed-in user | their job is approved or rejected, or their profile is verified |

## 3. Run, test, release

```bash
flutter run                                    # debug on a phone or emulator
flutter test                                   # unit and bloc tests
flutter analyze

# Use a different API, e.g. a local server
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api

# Release builds
flutter build appbundle --release              # Play Store (.aab)
flutter build ipa --release                    # App Store
```

For a Play Store release (signing key, target SDK, products, testers, listing), follow [RELEASE.md](RELEASE.md).

Whenever you change a class with `@injectable`, `@lazySingleton` or `@JsonSerializable`, run build_runner again. To regenerate on every save while developing, use `dart run build_runner watch --delete-conflicting-outputs`.

---

## Architecture

The app uses Clean Architecture with feature-first folders. Dependencies only point inward: presentation → domain ← data.

```
lib/
  main.dart                 Firebase init, DI, push init, runApp
  app/app.dart              MaterialApp.router, app-wide blocs, push → navigation bridge
  core/
    config/                 AppConfig (site, API URL via --dart-define, WhatsApp)
    di/                     get_it + injectable (injection.dart, register_module.dart)
    error/                  Exceptions (data layer) → Failures (domain) via guard()
    result/                 Result<T> = Success | Err (no throwing across layers)
    usecase/                UseCase<T, P> interface, NoParams
    network/                ApiClient (Dio), AuthInterceptor (Firebase ID token)
    router/                 go_router: 4 tabs (StatefulShellRoute) + sign-in redirect
    notifications/          PushService: permission, topics, device registration, taps
    theme/ utils/ widgets/  Shared look, formatters, validators, LinkLauncher, common widgets
  features/<feature>/
    domain/                 entities, repository interfaces, use cases (pure Dart)
    data/                   models (json_serializable), data sources, repository impls
    presentation/           blocs/cubits, pages, widgets
```

| Feature | Data source | State |
|---|---|---|
| auth | Firebase Auth (Google, email) | `AuthCubit` (app-wide) |
| jobs | Jobs API `/jobs`, `/meta`; saved jobs in SharedPreferences | `JobsBloc`, `JobDetailCubit`, `SavedJobsCubit` |
| profile | Jobs API `/talent/me`, photo, resume settings; PDF made on the phone | `ProfileCubit` (app-wide) |
| courses | Firestore `courses`, `settings/batch`, `registrations` | `CoursesCubit` (app-wide) |
| blog | `widgetryacademy.in/blog/feed.json` | `BlogCubit` |

How the design follows SOLID:

- **Single responsibility:** each use case does one thing (`SearchJobs`, `ToggleSavedJob`, `RegisterForCourse` …).
- **Open/closed:** job categories come from the server, so adding React Native needs one SQL migration and no app release. Resume templates are data.
- **Liskov substitution:** repositories and `LinkLauncher` are interfaces, and tests swap in mocks.
- **Interface segregation:** small interfaces per feature (`JobsRepository`, `ProfileRepository`, `ResumeBuilder`).
- **Dependency inversion:** blocs depend on use cases, use cases on interfaces, and injectable wires in the implementations.

### Adding a feature

1. Create `features/<name>/domain`: entities, a repository interface and use cases (`@injectable`).
2. Create `features/<name>/data`: models, a data source and `@LazySingleton(as: XRepository) class XRepositoryImpl`.
3. Create `features/<name>/presentation`: an `@injectable` cubit and the pages.
4. Add the route in `core/router/app_router.dart`.
5. Run `dart run build_runner build --delete-conflicting-outputs`.
6. Add tests in `test/features/<name>/`.

## Payments (Razorpay and Google Play)

Students pay the course fee inside the app. Prices are set on the server, never in the app.

- **Android (Play build):** Google's user choice screen comes first. The student picks **Google Play** or **Razorpay** (UPI, cards, net banking, wallets), as Play's India alternative billing rules require.
  - **Google Play:** the app sends the purchase token to `POST /api/payments/play/verify`. The server checks it with Google, records it like any other payment and then consumes it. Unfinished Google Play purchases are confirmed the next time the pay screen opens.
  - **Razorpay:** the flow below runs. The order carries Google's external transaction token and the student's state (asked on the pay screen and remembered). The server reports the sale to Google within minutes, retrying every 10 minutes.
  - **Setup:** products, enrolment, the service account and `ANDROID_BILLING` are covered in [RELEASE.md](RELEASE.md) steps 4 to 6.
- **iOS, and Android while `ANDROID_BILLING=razorpay`:** Razorpay only.

The Razorpay flow:

How a payment works:

1. **Order:** the app asks `POST /api/payments/order` for a plan. The server checks the student's registration and creates a Razorpay order for the right amount.
2. **Checkout:** the app opens Razorpay Checkout with that order.
3. **Confirmation, two ways:**
   - The app sends the result to `POST /api/payments/verify`. The server checks the signature and asks Razorpay that the money arrived.
   - Razorpay also calls `POST /api/payments/webhook`.

   Whichever arrives first updates the registration in Firestore. It uses the same fields as Admin → Registrations: `plan`, `amountPaid`, `payStatus` (`part-paid` / `paid`) and `paymentId`. It also sends a push notification.

| Plan | Pay now | Shown when |
|---|---|---|
| Early bird | ₹3,499 | until `seatsLeft` in Admin → Next batch is 0 (or `EARLY_BIRD=off`) |
| Pay in full | ₹4,999 | always |
| Book with a part payment | ₹2,500, then the balance | always; after it, only "Pay the balance" is offered |

**After paying**

- **Courses tab:** the course's sales card is replaced by **My course**. It shows the status (payment pending, seat booked with balance due, or seat confirmed), the batch start with a countdown, and a "Before Day 1" checklist (WhatsApp group, Flutter setup, first class).
- **Payments & receipts** (Settings, My course, or a tap on the payment notification): fee paid against total, balance due, and every in-app payment. Each payment opens a receipt with a shareable PDF.
- **Recovery:** if the app closed after paying, or the webhook was late, the server asks Razorpay about the student's recent unconfirmed orders whenever they open payments or try to pay again. A payment that went through is recorded, so nobody pays twice.

To change prices, set `PRICE_EARLY_BIRD`, `PRICE_REGULAR` and `PRICE_BOOKING` on Railway. If they change, update Admin → Registrations too.

**One-time setup**

1. **API keys:** in the Razorpay Dashboard → Account & Settings → API Keys, generate keys. Test keys start with `rzp_test_` and live keys with `rzp_live_`.
2. **Railway variables:** add these to the jobs API service. Type the secrets in Railway yourself, never in chat or in code.
   - `RAZORPAY_KEY_ID`
   - `RAZORPAY_KEY_SECRET`
   - `RAZORPAY_WEBHOOK_SECRET` (any long random text; you choose it in step 3)
   - `FIREBASE_SERVICE_ACCOUNT`, which is required here, because the server updates the registration in Firestore
3. **Webhook:** in the Razorpay Dashboard → Webhooks → Add new webhook:
   - URL: `https://api.widgetryacademy.in/api/payments/webhook`
   - Secret: the same `RAZORPAY_WEBHOOK_SECRET`
   - Events: `payment.captured`, `order.paid` and `payment.failed`
4. **Automatic capture:** in Razorpay → Payment capture, keep it on.
5. **Testing:** use test keys first. Razorpay's test UPI ID `success@razorpay` succeeds and `failure@razorpay` fails. Then switch both keys to live.

Until the keys are set, the app shows "In-app payment is coming soon" with a link to pay on the website.

**Android release builds:** `android/app/proguard-rules.pro` (in this repo) keeps Razorpay's classes. Flutter picks it up automatically.

## Mock interviews

One-to-one mock interviews with working engineers, paid with Razorpay. A live one-to-one session is exempt from Google Play Billing, so no Google fee applies.

**Candidates** (Home tile, Profile, Settings → Mock interviews):
1. Choose the track (Flutter, Android, iOS), level (Fresher ₹499, Mid ₹799, Senior ₹1,199) and round.
2. Pick an open slot. It's held for 15 minutes while they pay.
3. After paying, the booking shows the interviewer and, from 10 minutes before, a **Join call** button. A reminder is pushed about an hour before.
4. After the call they get a scorecard: five skills scored 1–5, what went well, what to work on, and a hire call. They can show the overall score on their profile.
5. Cancelling 24+ hours before puts the booking in "Refund due" (refund in Razorpay, then mark it refunded in Admin).

**Interviewers** (added in Admin → Interviews by the email they signed in with):
1. In the app, open Mock interviews → Interviewer dashboard, and add their Google Meet/Zoom link.
2. Add free slots (any day in the next 3 weeks, 45 or 60 minutes). Overlaps are skipped.
3. After each interview, tap the booking → **Write feedback**, or mark a no-show 15 minutes after the start.

Server: `src/mock.ts` and `src/routes/mock.ts`; tables in `migrations/011_mock_interviews.sql`. Prices: `PRICE_MOCK_FRESHER`, `PRICE_MOCK_MID`, `PRICE_MOCK_SENIOR` on Railway. Payment confirmation works like course fees: app, webhook, or recovery when the candidate opens their bookings.

## Widgetry Assistant (chat)

The app's chat gives the same answers as the website chatbot. The answers live in one place, `public/chatbot.js`, and are copied into the app's `assets/chatbot/intents.json`.

After editing answers on the website, run this from the repo root, then rebuild the app:

```bash
node mobile/tool/sync_chatbot.mjs
```

In the app, buttons that scroll to a section on the website (fees, syllabus, next batch, and so on) open the course screen instead. Website pages open in the in-app browser, and WhatsApp buttons open WhatsApp with the question filled in. The chat opens from the Courses tab ("Ask a question"), the course screen and Settings → Help.

## Design system

- **Colours:** in `core/theme/app_colors.dart`. `AppColors` holds the brand values from the website. `Palette.of(context)` gives the light/dark tokens (bg, surface, ink, muted, line, accent, hero).
- **Fonts:** DM Sans for text and Unbounded for the brand, via `google_fonts`. Use `AppTheme.display()` sparingly, for the wordmark, hero titles and prices.
- **Spacing and corners:** `Space` (4-point grid, 20 px page gutter) and `Radii`.
- **Shared widgets:** in `core/widgets/`. These include `BrandMark`, `Wordmark`, `Group` (settings-style lists), `SectionLabel`, `Fact`, `BottomActionBar`, `BusyLabel`, `SkeletonList` and the empty/error states. Use these instead of new one-off styles.

## Troubleshooting

| Problem | Fix |
|---|---|
| `DefaultFirebaseOptions have not been configured` | Run `flutterfire configure …` (step 1.4). |
| `injection.config.dart` or `*.g.dart` missing | Run `dart run build_runner build --delete-conflicting-outputs`. |
| Google sign-in fails on Android (error 10 / DEVELOPER_ERROR) | Add the SHA-1 and SHA-256 fingerprints in Firebase, then download `google-services.json` again. |
| Google sign-in fails on iOS | Add the Encoded App ID URL scheme (section 2). |
| "Can't reach the jobs server" | Check that `https://api.widgetryacademy.in/api/health` returns `{"ok":true}`. |
| No notifications on iOS | Upload the APNs key to Firebase, add the Push capability, and test on a real device. |
| Resume PDF fails offline the first time | The fonts download once and are cached. Offline, the PDF uses built-in fonts. |
