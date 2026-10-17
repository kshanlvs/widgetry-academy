# Releasing on Google Play

Package `in.widgetryacademy.app` · personal developer account · Flutter 3.44 or newer

Work through the steps in order. Steps 1 and 2 happen on your computer. Everything after that happens in Play Console, Railway and Google Cloud.

---

## 1. Prepare the build

```bash
flutter upgrade                 # 3.44+ (Google Play Billing Library 8 needs it)
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run flutter_launcher_icons            # app icon from assets/icon/
dart run flutter_native_splash:create      # launch screen
flutter test && flutter analyze
```

### `android/app/build.gradle.kts`

Keep the `plugins { … }` block and the Firebase lines you already have. Add the key loading at the top of the file, then make the `android { … }` block match this:

```kotlin
import java.io.FileInputStream
import java.util.Properties

val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

android {
    namespace = "in.widgetryacademy.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "in.widgetryacademy.app"
        minSdk = 23
        targetSdk = 36                 // Play requires API 36 for new apps
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    // keep your existing compileOptions / kotlinOptions blocks
}
```

### Upload key (once)

On Windows, use Android Studio's keytool. Keep the `.jks` file and its passwords safe, outside the repo, and back them up. If you lose them you must ask Google to reset the upload key.

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v -keystore C:\keys\widgetry-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then create `android/key.properties`. It is already in `.gitignore`, so never commit it.

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=C:/keys/widgetry-upload.jks
```

### Build

```bash
flutter build appbundle --release --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID.apps.googleusercontent.com
```

The output is `build/app/outputs/bundle/release/app-release.aab`.

Before every new upload, raise the version in `pubspec.yaml`, e.g. `1.0.0+1` → `1.0.1+2`. The number after `+` must always go up.

## 2. Google sign-in fingerprints

Google sign-in fails in the Play build unless Firebase knows these keys. In Firebase → Project settings → Android app (`in.widgetryacademy.app`) → **Add fingerprint**, add SHA-1 and SHA-256 for:

1. **Your upload key:**
   ```powershell
   & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -keystore C:\keys\widgetry-upload.jks -alias upload
   ```
2. **Google's app signing key:** after your first upload, it's in Play Console → Test and release → App integrity → App signing.

Then download `google-services.json` again into `android/app/` and rebuild.

---

## 3. Play Console: create the app

Go to Play Console → **Create app**:

- **Name:** Widgetry Academy
- **Default language:** English (India), en-IN
- **App or game:** App
- **Free or paid:** Free (the course fee is an in-app purchase)

Then fill in **App content** (Policy → App content):

| Item | Answer |
|---|---|
| Privacy policy | `https://widgetryacademy.in/privacy.html` |
| App access | "All functionality is available without special access." Jobs, courses and guides work signed out; profile and payments work with any Google account or a new email account. |
| Ads | No ads |
| Content rating | Category: Education / Reference. Answer **No** to violence, sexual content, language, drugs and gambling. "Users interact or exchange content": **No**. "Digital purchases": **Yes**. |
| Target audience | **18 and over**. Add 16–17 only if you advertise to school students; that adds extra review. |
| News app | No |
| Financial features | None. Taking payments for your own course doesn't count. |
| Health | No |
| Government app | No |
| Data safety | See section 7 below |
| Account deletion | URL: `https://widgetryacademy.in/delete-account.html`. In app: Profile → Settings → Delete account. |

## 4. Payments in the app (India user choice billing)

Play's rules require Google Play Billing for selling a course inside the app. With India user choice billing, Google shows students **Google Play** and **Razorpay** side by side. The app and server already handle both.

1. **Merchant account:** go to Play Console → Settings → Payments profile, and set up a merchant account. It's needed before you can create products.
2. **Enrol in alternative billing:** in Play Console's top search, type **"alternative billing"** and open the enrolment page/form for **user choice billing in India**. It asks for details of your other billing system (Razorpay), and Google must approve it. While waiting, keep `ANDROID_BILLING=razorpay` on Railway (see step 6). That is fine for internal testing only.
3. **First upload:** upload the `.aab` to **Internal testing** first. Play only lets you create products after a build that uses billing has been uploaded.
4. **Products:** in Monetize → Products → **One-time products**, create these four. The IDs must match exactly, and the prices must equal the server's prices:

   | Product ID | Name | Price (INR) |
   |---|---|---|
   | `course_fee_early_bird` | Flutter in 10 Days: early bird | 3,499 |
   | `course_fee_full` | Flutter in 10 Days: full fee | 4,999 |
   | `course_fee_booking` | Flutter in 10 Days: seat booking | 2,500 |
   | `course_fee_balance` | Flutter in 10 Days: balance | 2,499 |

   If you change `PRICE_*` on Railway, change the Play prices on the same day. The server offers a Play product only when its price matches the server's amount. Otherwise that payment goes through Razorpay.

5. **Licence testers:** go to Settings → License testing and add the Gmail addresses you test with, so test purchases are free.

**Fees:** Google takes its service fee on Google Play purchases. On Razorpay payments chosen on Google's screen, the fee is 4 percentage points lower. The server reports each Razorpay sale to Google automatically within minutes, and Google bills that fee monthly.

## 5. Give the server access to Google Play

The server checks Google Play purchases and reports Razorpay sales. It uses the same Firebase service account.

1. **Enable the API:** in Google Cloud Console (project **flutter-in-10-days**), go to APIs & Services → Library and enable **Google Play Android Developer API**.
2. **Invite the service account:** in Play Console → Users and permissions → **Invite new users**, enter the service account's email. It's the `client_email` in the key you put on Railway, ending in `@flutter-in-10-days.iam.gserviceaccount.com`.
3. **Permissions:** under App permissions, add Widgetry Academy with **View financial data** and **Manage orders and subscriptions**.

Access can take up to 24 hours to start working.

## 6. Railway variables (jobs API)

| Variable | Value |
|---|---|
| `ANDROID_BILLING` | `razorpay` until Google approves step 4.2, then **delete it** (the default is `user_choice`) |
| `PLAY_PACKAGE_NAME` | optional; defaults to `in.widgetryacademy.app` |
| `PLAY_SERVICE_ACCOUNT` | optional; defaults to `FIREBASE_SERVICE_ACCOUNT` |
| `GST_PERCENT` | `0` unless you're GST-registered (used to split tax when reporting to Google) |
| Razorpay | switch `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET` to **live** keys and add the live-mode webhook before production |

The database update (`010_play_billing.sql`) runs by itself when the server starts.

## 7. Data safety form

Answer for the app together with its SDKs (Firebase, Razorpay, Google Play Billing).

- **Data is encrypted in transit:** Yes.
- **Users can request deletion:** Yes, at `https://widgetryacademy.in/delete-account.html`.

| Data type | Collected | Shared | Optional | Why |
|---|---|---|---|---|
| Name | Yes | No | No (sign-in) | Account management, app functionality |
| Email address | Yes | No | No | Account management, communications |
| User IDs | Yes | No | No | Account management |
| Phone number | Yes | No | Yes | App functionality (course contact, profile) |
| Other info (city, headline, skills, links, salary expectations) | Yes | No | Yes | App functionality (Talent Network profile) |
| Photos | Yes | No | Yes | App functionality (profile photo) |
| Purchase history | Yes | No | Yes | App functionality, fraud prevention (course payments) |
| Other user-generated content (job reports) | Yes | No | Yes | App functionality, fraud prevention |
| Device or other IDs (notification token) | Yes | No | Yes | App functionality (notifications) |

**Shared: No.** The profile reaches an employer only when the student approves it each time. Google treats a transfer the user starts with consent as not "sharing". Payment card and UPI details go straight to Razorpay or Google, and the app never sees them.

Not collected: location, contacts, messages, health, files, web history, and the text typed into the assistant (it answers on the phone).

Razorpay publishes its own Data safety guidance for its SDK. Check it in their docs and add anything it lists, e.g. device IDs for fraud prevention.

## 8. Store listing

Go to Grow → Store presence → Main store listing. The images are in `store/`.

- **App icon:** `store/play-icon-512.png`
- **Feature graphic:** `store/feature-graphic-1024x500.png`
- **Phone screenshots:** 4 to 8, portrait, at least 1080 × 1920. Good ones are the jobs list, a job, your profile and resume, My course, and the assistant. Take them on a phone with `flutter run --release`.

**App name** (30 characters max)

> Widgetry Academy: Dev Jobs

**Short description** (80 characters max)

> Flutter, Android & iOS jobs, a free ATS resume and live Flutter courses.

**Full description**

> Find your next mobile developer job and get ready for it, in one app.
>
> **Jobs for mobile developers**
> Flutter, Android and iOS roles from real companies, checked by our team before they go live. Search by skill, city, remote or hybrid, experience and salary. Save jobs, get alerts for new roles in your stack, and apply on the company's own careers page. No fees to apply, ever.
>
> **A resume that gets past the filters**
> Build your Talent Network profile once and download a clean, ATS-friendly PDF resume in three styles. A profile score shows what to add next. Get verified by our team and let employers find you, but only with your approval.
>
> **Learn Flutter live**
> Flutter in 10 Days: live weekend classes taught by engineers who ship apps for a living. See batch dates, register, pay securely and follow everything about your batch: countdown to Day 1, setup checklist, receipts and the class group.
>
> **Guides and help**
> Career guides for Flutter developers, and a built-in assistant that answers questions about courses, fees and jobs instantly.
>
> Your data stays yours: no ads, no tracking, and you can delete your account any time from Settings.
>
> Widgetry Academy · Kolkata · widgetryacademy.in

- **Category:** Education
- **Tags:** Education, Jobs
- **Contact email:** your contact email
- **Website:** `https://widgetryacademy.in`

## 9. Testing, then production

A new personal account must run a **closed test with at least 12 testers, opted in for 14 days in a row**, before it can apply for production.

1. **Internal testing:** upload the `.aab`, add yourself, and install from the opt-in link. Check:
   - Sign-in, jobs, profile and resume.
   - A Google Play test purchase and a Razorpay test payment, from **Pay** on the course.
   - Payments & receipts.
   - Delete account, using a spare account.
2. **Closed testing:** create a track, add at least 12 testers (a Google Group is easiest), and share the opt-in link. Testers must **opt in and keep the app installed for 14 days**. Ask them to open it a few times; Google looks at engagement.
3. **Apply for production:** after 14 days, go to Dashboard → **Apply for production** and answer the questions about your testing.
4. **Production:** after approval, promote the build. Start with a staged rollout of 20% and watch Android vitals, then go to 100%.

## Every later release

1. Raise the version in `pubspec.yaml`.
2. Run `flutter test`.
3. Run `flutter build appbundle --release --dart-define=GOOGLE_WEB_CLIENT_ID=…`.
4. Upload to Production with release notes, using a staged rollout.
