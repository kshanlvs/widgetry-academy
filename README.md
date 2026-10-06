# Widgetry Academy website: Firebase setup (free Spark plan)

Project: **flutter-in-10-days**. The config is already filled in. Nothing here needs billing.

## How seat reservation works
1. The student fills in name, class/course, email, WhatsApp number and experience.
2. The seat is saved to Firestore straight away with status **reserved**.
3. Optional: the student can tap **Send verification email**.
4. If they verify, the reservation is marked **verified**.

The same email can't register twice. Security rules only let a reservation become "verified" after Firebase confirms the email.

The phone number is saved but **not OTP-verified**, because SMS needs the paid Blaze plan.

## One-time setup in the Firebase console (2 minutes)
1. **Authentication → Get started → Sign-in method → Email/Password → Enable → Save.** Leave "Email link" off; it isn't needed.
2. **Firestore Database → Create database → location `asia-south1 (Mumbai)` → Production mode.**
3. Optional: **Authentication → Templates → Email address verification**. Set the sender name (e.g. "Flutter in 10 Days") and edit the message.

## Deploy (on your computer)
Requires Node.js (https://nodejs.org).
```bash
npm install -g firebase-tools
firebase login
cd flutter-workshop-firebase
firebase deploy --only hosting,firestore:rules
```
Live at **https://widgetry-academy.web.app**

### First time only: create the widgetry-academy site
```bash
firebase hosting:sites:create widgetry-academy
```
Then in the Firebase console: **Authentication → Settings → Authorized domains → Add domain → `widgetry-academy.web.app`**.

## See reservations
**Firestore Database → registrations.** Each entry has:
`name, level, experience, email, phone, emailVerified, status (reserved | verified), batch, createdAt, verifiedAt`

## Free plan limits (Spark)
- Verification emails: 1,000/day
- Firestore: 50,000 reads and 20,000 writes per day, 1 GB storage
- Hosting: 10 GB storage, 360 MB/day transfer

That is far more than a workshop needs.

## Adding phone OTP later (paid)
SMS OTP requires upgrading to Blaze (about ₹6 per SMS to Indian numbers). Ask Claude to switch it back on when you're ready.

## Payments (Razorpay)
Edit `public/site-config.js`:
- `razorpay.earlyBird`, `razorpay.regular`, `razorpay.booking`: paste each Payment Button ID (`pl_...`). Empty = shows "Online payment opening soon".
- `contactEmail`, `contactPhone`, `address`: shown on the Contact and policy pages (Razorpay checks these before approving live payments).
Then run `firebase deploy --only hosting`.

Policy pages: `terms.html`, `privacy.html`, `refund.html`, `contact.html` (linked in the footer).
When switching Razorpay from Test to Live mode, create the live buttons and replace the IDs.

## Next batch, WhatsApp, Meta Pixel (public/site-config.js)
- `batch.startDate`, `batch.time`, `batch.mode`, `batch.demo`, `batch.seatsLeft`: shown in the hero and Fees section.
- `whatsapp`: digits with country code (e.g. `919876543210`). Turns on the floating "Chat with us" button and the "Book free demo" button.
- `metaPixelId`: your Meta Pixel ID. Tracks PageView, Lead (seat reserved), InitiateCheckout (pay button) and Purchase (thank-you page).

## Admin page (https://widgetry-academy.web.app/admin.html)
1. Firebase console → Authentication → Users → **Add user**: your admin email + a strong password.
2. Copy that user's **User UID**.
3. In `firestore.rules`, replace `PASTE_ADMIN_UID_HERE` with the UID.
4. `firebase deploy --only hosting,firestore:rules`
5. Open `/admin.html` and sign in. You can search, filter, mark payments (plan, amount, Razorpay payment ID, status, notes) and export CSV.
