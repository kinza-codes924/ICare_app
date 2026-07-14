# iCare App (wajahat) — Claude Context

## Project overview
iCare Virtual Hospital — full healthcare platform (patients, doctors, labs, pharmacies, instructors/students, admin). Flutter app (web + mobile) with Node.js/Express + MongoDB (Mongoose) backend, both deployed on Vercel.

**Major feature areas:** appointments & booking, video consultations (Jitsi, migrated from Agora/Zego), Connect Now (instant doctor connect), chat, prescriptions (v2/enhanced), medical records, patient history, lab tests & lab supplies, pharmacy & product store (cart/orders/invoices), LMS (courses, live sessions, quizzes, assignments, certificates, polls, attendance, lesson notes), community forum, gamification, health trackers/profiles/reminders, clinical audit, admin panel & verification, notifications (FCM), ratings/reviews, vouchers.

## Codebase map
- **Frontend (Flutter, repo root)**: `lib/screens/` (~258 files), `lib/services/` (~59 API service classes), `lib/models/` (~35), `lib/widgets/` (~62), `lib/utils/` (web/stub platform-split helpers, Jitsi launcher, theme, api_constants), `lib/navigators/` (go_router `app_router.dart`, bottom tabs, drawer), `lib/providers/` (Riverpod: auth, chat, common).
- **Backend (`icare-backend/`)**: `index.js` entry; `routes/` (~50 route files incl. auth, appointments, consultation-v2, prescription-v2, jitsi-token, live-sessions, courses, labs, pharmacy, admin), `models/` (~45 Mongoose models), plus controllers/services/middleware/config.
- **Key deps**: frontend — Riverpod, go_router, dio, firebase (core/auth/messaging), easy_localization, agora_rtc_engine + zego (legacy, mobile), pdf/printing, fl_chart. Backend — express 5, mongoose, jsonwebtoken, cloudinary, @vercel/blob, nodemailer, firebase-admin, pdfkit.
- Fonts: Gilroy. Translations in `assets/translations/`.
- Root has many status/report `.md` files documenting past fixes (LMS, lab, consultation, etc.).

## Project info
- **Frontend**: Flutter Web at https://www.icare.com.co/ (Vercel project: `icare-app`)
- **Backend**: Node.js/Express at https://icare-backend-inky.vercel.app (Vercel project: `icare-backend`)
- **Jitsi server**: Self-hosted on DigitalOcean droplet `167.99.65.120`, domain `167-99-65-120.nip.io`
- **Deploy command**: `vercel deploy --prod` (for BOTH frontend and backend separately)
- **After every flutter build**: must patch `build/web/flutter_bootstrap.js` — add `config: { canvasKitBaseUrl: "/canvaskit/" }` to the loader.load() call

## What we use Jitsi for
1. **LMS Live Sessions** — instructor starts a live class, students join
2. **Doctor/Patient Consultation** — 1:1 video call

## Self-hosted Jitsi details
- Domain: `167-99-65-120.nip.io`
- JWT auth: HS256, `context.user.moderator` claim
- Prosody plugin: `mod_token_affiliation_legacy.lua` — sets MUC owner/member from JWT moderator claim
- Jicofo: `enable-auto-owner=0` — prevents first-joiner from auto-getting moderator
- `enableUserRolesBasedOnToken` is intentionally NOT set (caused self-promotion bug)
- Jibri: server-side recording, 1 Jibri instance = 1 room at a time

## Key files changed (Jitsi migration from Agora)

### Frontend (Flutter)
- `lib/utils/lms_agora_web.dart` — Jitsi External API JS interop for LMS (web)
- `lib/utils/lms_agora_stub.dart` — Mobile stub (opens Jitsi in browser via url_launcher)
- `lib/screens/lms_live_session_screen.dart` — LMS live session screen (uses Jitsi)
- `lib/screens/video_call_web.dart` — Doctor/patient consultation (uses Jitsi)
- `lib/services/lms_service.dart` — has `getJitsiToken()` method
- `web/index.html` — Jitsi JS functions + CSP with 167-99-65-120.nip.io

### Backend (Node.js)
- `icare-backend/routes/jitsi-token.js` — generates JWT for Jitsi
  - moderator=true only if DB confirms user is session instructor (for LMS)
  - moderator=true only for doctors (role check, for consultation)
- `icare-backend/routes/live-sessions.js` — stale session cleanup + Jibri recording endpoint
- `icare-backend/models/LiveSession.js` — added `recordings[]` array + `ended`/`rescheduled` status

## Environment variables needed (Vercel `icare-backend` project)

**MUST BE SET before Jitsi JWT auth works:**
```
JWT_APP_ID      = (get from /etc/prosody/conf.d/*.cfg.lua on 167.99.65.120 — look for app_id)
JWT_APP_SECRET  = (get from prosody config — look for app_secret)
JIBRI_UPLOAD_SECRET = (must match what's set in Jibri finalize script on the server)
```

To add to Vercel:
```powershell
cd icare-backend
vercel env add JWT_APP_ID production
vercel env add JWT_APP_SECRET production
vercel env add JIBRI_UPLOAD_SECRET production
```

## Jitsi JS functions in web/index.html

### For consultation (doctor/patient):
- `jitsiJoin(roomName, displayName, audioOnly, jwt)` → Promise
- `jitsiLeave()` → Promise
- `jitsiIsClosed()` → bool
- `jitsiIsRemoteJoined()` → bool
- `jitsiIsRemoteLeft()` → bool

### For LMS live sessions:
- `lmsJitsiJoin(roomName, displayName, isInstructor, jwt, subject)` — auto-starts Jibri recording for instructor
- `lmsJitsiLeave()`
- `lmsJitsiIsClosed()` → bool
- `lmsStopRecording()` — MUST call before leave (triggers Jibri finalization + upload)

## Key architectural decisions
- Jibri finalize script runs on Jitsi server → calls backend `/api/live-sessions/jibri-recording-complete`
- Jibri recordings stored via Cloudinary (bypasses Vercel 4.5MB limit)
- Stale live sessions (no instructor heartbeat > 5 min) auto-set to 'ended' on next course fetch
- Platform view: `lms-jitsi-host` div registered via `ui.platformViewRegistry` for Jitsi iframe
- After Jitsi ends: `lmsHardRedirect('/dashboard')` (full page reload — SPA navigation breaks Jitsi platform views)

## Safepay payment gateway (added Jul 2026)
- **Backend**: `routes/payments.js` (create/verify/webhook/my/logs/all), `models/Payment.js` (status: created→pending→paid/failed/expired, `fulfilled` flag = idempotent), `models/PaymentLog.js` (append-only audit trail, level ALERT on signature/amount mismatch).
- Amount ALWAYS server-calculated (`calculateAmount()` — currently only type `course`; appointment/lab/pharmacy pending). PKR ×100 lowest denomination sent to Safepay.
- Express Checkout flow: POST `/order/payments/v3/` (session) → POST `/client/passport/v1/token` (tbt) → hosted URL `{host}/embedded/?tracker&tbt&environment&source=hosted&redirect_url&cancel_url`. Auth header: `X-SFPY-MERCHANT-SECRET`.
- Webhook: HMAC-SHA512 hex of raw body vs `X-SFPY-SIGNATURE` (rawBody captured in index.js express.json verify). Fulfillment (enrollment create + voucher redeem) only on `payment.succeeded`/TRACKER_ENDED + amount match.
- `routes/courses.js` /enrollments now has a payment gate: paid course without a `paid` Payment → 402 paymentRequired.
- **Frontend**: `lib/services/payment_service.dart` (createPayment/verifyPayment/pollUntilPaid), `select_payment_method.dart` — course purchases open Safepay hosted checkout (url_launcher) and poll verify; fake card list remains for lab/appointment (not yet migrated).
- **Env vars needed (icare-backend Vercel)**: `SAFEPAY_API_KEY`, `SAFEPAY_SECRET_KEY`, `SAFEPAY_WEBHOOK_SECRET`, `SAFEPAY_ENV` (sandbox|production). Webhook endpoint to register in Safepay dashboard: `https://icare-backend-inky.vercel.app/api/payments/webhook`.

## How to deploy
```bash
# (Mac — project lives at ~/icare)
# Backend
cd ~/icare/icare-backend
vercel deploy --prod

# Frontend
cd ~/icare
flutter build web --release --no-wasm-dry-run
# Then patch build/web/flutter_bootstrap.js:
# change: _flutter.loader.load({ serviceWorkerSettings: {...} });
# to:     _flutter.loader.load({ serviceWorkerSettings: {...}, config: { canvasKitBaseUrl: "/canvaskit/" } });
vercel deploy --prod
```
