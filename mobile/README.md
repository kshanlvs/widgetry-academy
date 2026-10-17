# Widgetry Academy app

The Android and iOS app for widgetryacademy.in. It covers:

- **Jobs:** Flutter, Android and iOS jobs with search, filters, saving and reporting. Apply opens the employer's own careers page.
- **Profile and resume:** a Talent Network profile with a profile score and photo, plus an ATS-friendly PDF resume (Modern, Classic or Compact) to share or print.
- **Courses:** the course list, batch details and registration (it uses the same Firestore format as the website).
- **Guides:** the blog, read from `blog/feed.json`.
- **Push notifications:** new jobs by category, academy news, and personal alerts such as "your job is live" or "you're verified".

Package / bundle ID: `in.widgetryacademy.app` · Flutter 3.35 or newer · Dart 3.8 or newer

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

Set the label inside `<application>`: `android:label="Widgetry Academy"`.

### iOS: `ios/Runner/Info.plist`

```xml
<key>CFBundleDisplayName</key><string>Widgetry Academy</string>
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

For a Play Store release, set up a signing key first. Flutter's guide covers it: "Build and release an Android app" → "Signing the app". Keep the keystore and passwords out of git.

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
