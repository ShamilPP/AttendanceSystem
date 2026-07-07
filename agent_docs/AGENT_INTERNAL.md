# AGENT_INTERNAL — AI-Managed Project Brain

> **FOLDER RULES (read first, every session):**
> - `agent_docs/` is 100% AI-managed. Humans do not read or edit it. Write for a future AI session, not for a person.
> - This file (`AGENT_INTERNAL.md`) is the MAIN INDEX. Hard limit ~500 lines. If more space is needed, create a new file in `agent_docs/` and **always** list it in the "File index" section below — a spillover file that is not indexed here is considered lost.
> - **MUST update this file after every major/important change** (new features, architecture decisions, status changes, gotchas discovered, credentials/config changes). Add a dated entry to the "Update log". This file is the key to restoring context when the user returns after a long gap.
> - The user (shamilpp4115@gmail.com) may return with zero memory of the project state. This file must be sufficient to fully restore context.

## File index (agent_docs/)

| File | Purpose |
|---|---|
| `AGENT_INTERNAL.md` | This file — main index, status, key context. |

(No spillover files yet. Create e.g. `BACKEND_DETAILS.md`, `DECISIONS.md` here when this file nears 500 lines, and index them above.)

**Shared source-of-truth docs (in `docs/`, NOT agent_docs):** `API_CONTRACT.md` (REST contract, now v2), `DESIGN_SPEC.md` (shared Flutter design system — added 2026-07-08), `PLAN.md` (original product req).

---

## 1. What this project is

**Employee Attendance Management System** for 1NexCrew (dir: `/Users/shamil/Documents/ShamilProjects/1NexCrew/AttendaceSystem`).
Employees mark attendance by scanning an **encrypted rotating QR code** displayed at the office; the server validates QR authenticity/freshness AND **GPS geofence** before recording. Admins manage employees, correct attendance, configure the office location, and export Excel reports.

Three apps, one contract:

| Path | App | Stack |
|---|---|---|
| `backend/` | REST API | Node.js 26, Express, Mongoose/MongoDB, JWT, exceljs, multer, dayjs |
| `mobile_app/` | Employee app | Flutter 3.44 (Android+iOS), provider, mobile_scanner, geolocator |
| `admin_panel/` | Admin panel | Flutter Web, provider, fl_chart, qr_flutter |

**Sources of truth (in priority order):**
1. `docs/API_CONTRACT.md` — the FULL REST contract (endpoints, shapes, enums, status codes, validation order). All apps were built against it. **When code and contract disagree, the contract wins.** Never change one side without the others.
2. `docs/PLAN.md` — original product requirements (user-provided).
3. Root `README.md` — human-facing setup guide.

**NOT a git repository** (as of 2026-07-07). If initializing git later: .gitignore must exclude `node_modules/`, `backend/.env`, `backend/uploads/*`, Flutter `build/`, `agent_docs/` stays IN the repo (it is the project brain).

## 2. Current status — v2 COMPLETE & VERIFIED (2026-07-08)

**THE SYSTEM IS BUILT AND VERIFIED at v2. All three apps done; §3/§4 below reflect v2.**
v1 was built+verified 2026-07-07 (see Update log). On 2026-07-08 the user requested v2: (1) remove breaks entirely, (2) single context-aware Check-In/Check-Out button, (3) permanent QR (regenerate-only), (4) full modern redesign of both Flutter apps. Done via 3 parallel Agent subagents (one per app) against the updated `docs/API_CONTRACT.md` v2 + new `docs/DESIGN_SPEC.md`, then INDEPENDENTLY re-verified by the main agent.

| Component | v2 status | Independent verification (main agent, not just the builder's self-check) |
|---|---|---|
| `backend/` | ✅ DONE | ✅ 17/17 smoke checks: stable qrData across GETs, employee 403 on qr/current, regenerate→v2 invalidates old code (old→403, new→200), BREAK_START→400, no `breaks`/`breakMinutes`/`onBreak`/`qrRefreshSeconds` in any response, geofence still enforced. Builder's own run: 43/43. |
| `mobile_app/` | ✅ DONE | ✅ `flutter analyze` clean; 18/18 tests. Single-button Home (Check In→Check Out→"Completed for today"). |
| `admin_panel/` | ✅ DONE | ✅ `flutter analyze` clean; 3/3 tests; `flutter build web --release` succeeds. Permanent-QR page + Regenerate button. |
| Repo-wide grep | ✅ | No `breakMinutes/BREAK_*/onBreak/ON_BREAK/qrRefreshSeconds/BreakEntry` in js/dart (only 2 code comments mention the word "breaks"). |

Nothing left running; DB re-seeded pristine.

**NEXT STEPS when user returns (nothing broken):**
1. Human-in-the-loop demo still never done on a real device — the top follow-up (backend → admin QR Display kiosk → scan from mobile). Now also worth eyeballing the NEW redesign live on both apps.
2. Optional `git init` (never asked).
3. Production hardening backlog: disable cleartext HTTP/ATS, restrict `CORS_ORIGIN`, rotate committed `.env` secrets, HTTPS, `Access-Control-Expose-Headers: Content-Disposition`.
4. Possible extensions: leave module, push notifications, reactivating soft-deleted employees (needs contract change — `isActive` not a write field).
Built in one session on 2026-07-07 via a multi-agent workflow (`wf_ba04ad97-10a`: 3 parallel builders → independent adversarial verifiers; 6 agents, ~588k tokens, ~28 min). Nothing is left running: no server on port 5000, DB was re-seeded to pristine; `mongod` (system service) left running.

| Component | Build | Verification result |
|---|---|---|
| `backend/` | ✅ DONE | ✅ **PASSED** — independent e2e verifier ran the FULL contract against live server+MongoDB: all 12 check groups (auth, roles, QR, geofence 403 w/ distance msg, state-machine 409s, breaks math, summary counts, request approval application, live view, correction+recompute, dashboard/trends point counts, employees CRUD + xlsx export (PK header) + import w/ per-row errors, dept in-use 409, office-settings persistence, document ownership 403s + byte-identical downloads, all 4 reports json+xlsx, envelope everywhere) |
| `mobile_app/` | ✅ DONE | ✅ **PASSED** — analyze 0 issues; 18/18 model tests; contract spot-checks (scan body, Bearer, permissions flows, manifests) OK |
| `admin_panel/` | ✅ DONE | ✅ **PASSED** — analyze 0 issues; 3/3 tests; `flutter build web --release` succeeded; all 10 nav sections present; endpoints match contract exactly; xlsx downloads carry Bearer + save via Blob |
| Root `README.md`, `docs/API_CONTRACT.md` | ✅ DONE | — |

**NEXT STEPS when user returns (nothing is broken; these are follow-ons):**
1. Human-in-the-loop demo: start backend, open admin panel (`flutter run -d chrome`), QR Display page, scan from mobile app on device/emulator (change baseUrl for Android emulator — Gotcha 3). Never manually demoed end-to-end by a human yet (machine-verified only).
2. Optional: `git init` + first commit (user never asked; .gitignore guidance in §1).
3. Production hardening backlog (all currently dev-mode by design): disable cleartext HTTP/ATS exceptions, restrict `CORS_ORIGIN`, rotate committed `.env` secrets, HTTPS, consider `Access-Control-Expose-Headers: Content-Disposition` on backend so browsers see xlsx filenames (admin panel has fallback names — works fine without).
4. Possible product extensions user may ask for: leave management module (currently ON_LEAVE via manual entry/requests only), push notifications, reactivating soft-deleted employees from admin UI (isActive is not a contract write field — would need a contract change first).

## 3. Critical data (credentials, config, defaults)

Seeded by `cd backend && npm run seed` (idempotent, wipe-and-recreate DB `attendance_system`):

- **Admin:** `admin@company.com` / `Admin@123`
- **Employees:** `emp1@company.com` … `emp8@company.com` / `Employee@123` (8 employees, 3 departments, 4 designations)
- **Office settings (singleton doc):** lat `25.1972`, lng `55.2744` (Dubai), radius `150` m, hours `09:00–18:00`, late/early tolerance `10` min, timezone `Asia/Dubai` (v2: NO `qrRefreshSeconds`)
- **Backend env** (`backend/.env`, real values exist locally; `.env.example` committed): `PORT=5000`, `MONGODB_URI=mongodb://127.0.0.1:27017/attendance_system`, `JWT_SECRET` (random), `JWT_EXPIRES_IN=7d`, `QR_SECRET` (32-byte base64), `CORS_ORIGIN=*`
- **Base URL everywhere:** `http://localhost:5000/api/v1`
- **JWT payload:** `{ sub: userId, role, employeeId }`, HS256
- **QR scheme (v2 — PERMANENT/static):** `QrConfig` singleton model stores `{token, version, qrData, generatedAt}`. `qrData` = AES-256-GCM over `{token, v: version}`, encoded `base64(iv):base64(ct):base64(authTag)`, key from env `QR_SECRET`. `GET /qr/current` [admin] serves the SAME stored `qrData` every call (lazily creates v1 if none). `POST /qr/regenerate` [admin] mints a new token, version+1, invalidates the old. **Validation is token-match, NOT time-freshness** — an old code's token no longer equals the stored one → 403. Admin panel renders once (no countdown/auto-refresh) + Regenerate button w/ confirm. Mobile treats qrData as opaque scanned text.
- **Response envelope:** success `{success:true, data, pagination?}` / error `{success:false, message, errors?}`. Status codes: 400 validation, 401 auth, 403 role/QR/geofence, 404, 409 conflict/duplicate.
- **Attendance enums (v2):** status `PRESENT|LATE|ABSENT|ON_LEAVE|HALF_DAY`; scan action `CHECK_IN|CHECK_OUT` (NO breaks); request type `MISSED_CHECK_IN|MISSED_CHECK_OUT|FULL_DAY|LEAVE`; request status `PENDING|APPROVED|REJECTED`; liveStatus `NOT_IN|WORKING|CHECKED_OUT|ON_LEAVE` (NO ON_BREAK).
- **Attendance record (v2):** NO `breaks`/`breakMinutes`. `workMinutes` = full checkIn→checkOut span (0 while open).
- **Scan validation order (backend, do not reorder):** ① QR decrypt + token matches current stored token (403 "Invalid or expired QR code") → ② geofence haversine ≤ radius (403 with "(Xm away, limit Ym)") → ③ state machine: CHECK_IN once/day (409 repeat); CHECK_OUT needs prior check-in (400 if none), second CHECK_OUT 409.

**Backend interpretation choices where the contract is silent (documented so nobody "fixes" them):**
- "Present" headcounts include LATE and HALF_DAY (contract: "LATE counts as present"); `attendanceRate` is a rounded integer.
- `employeeId` params (query or body) accept EITHER a Mongo `_id` OR an `EMP-####` business code — the admin panel sends EMP codes.
- Daily report returns one row per active employee (status ABSENT when no record exists).
- Admin user is seeded as `ADM-0001` with no department.
- `backend/.env` is committed WITH real generated secrets (dev convenience, deliberate); `.env.example` has placeholders.
- `GET /qr/current` is admin-only — the mobile app can never fetch it, only scan rendered codes.
- Admin panel persists its JWT via `shared_preferences` (mobile app uses `flutter_secure_storage`).

## 4. Gotchas & environment quirks (hard-won, do not rediscover)

1. **Port 5000 vs macOS AirPlay:** macOS ControlCenter (AirPlay Receiver) holds wildcard `*:5000`. `backend/src/server.js` handles EADDRINUSE by explicitly binding `127.0.0.1:5000` + `::1:5000`, so `localhost:5000` works either way. Don't "fix" port conflicts by changing PORT; the fallback already works.
2. **Flutter dependency pin (mobile_app):** `geolocator` is pinned `^13.0.4` (NOT 14.x) because geolocator 14 + any recent `file_picker` have an unresolvable transitive `win32` conflict. Mobile Dart APIs are identical. Don't bulk-upgrade pubspec without checking this.
3. **Android emulator networking:** mobile app must use `10.0.2.2` instead of `localhost` — constant in `mobile_app/lib/config/api_config.dart`. Physical device → LAN IP. Cleartext HTTP is enabled for dev (AndroidManifest `usesCleartextTraffic`, iOS ATS AllowsArbitraryLoads); remove for production.
4. **minSdk 23** on Android (mobile_scanner requirement).
5. **MongoDB** must be running locally (`mongod` via Homebrew; `mongosh` NOT installed). Check: `nc -z 127.0.0.1 27017`.
6. **Flutter Web downloads (admin_panel):** use `package:web` + `dart:js_interop` Blob/anchor (dart:html is deprecated on Flutter 3.44). xlsx downloads fetch bytes with the Bearer token then save — do NOT switch to plain URL navigation (loses auth header).
7. **Stray root `build/` dir:** a builder once created `<root>/build/ios/SourcePackages` (Xcode SwiftPM cache at wrong cwd). Deleted 2026-07-07. If it reappears at repo root (not inside app dirs), safe to delete.
8. Timezone math (late/early/workingDays) uses office-settings timezone (`Asia/Dubai`) via dayjs utc+timezone plugins, NOT server local time.
9. **DB state is disposable in dev:** verifiers/smoke tests leave records behind (e.g. an ON_LEAVE manual entry for EMP-0002 on 2026-07-06 with note "smoke test"). `cd backend && npm run seed` wipes and recreates everything — run it before any demo. There is deliberately NO attendance-delete endpoint (corrections only, for auditability).
10. Browsers can't read the xlsx `Content-Disposition` filename unless the backend adds `Access-Control-Expose-Headers: Content-Disposition`; admin panel falls back to sensible generated filenames — cosmetic, not a bug.
11. **(v2) `google_fonts` (Inter) fetches the font at runtime on first launch** — needs network the first time; offline it falls back to a bundled font, so it never breaks `flutter test`/builds. Both Flutter apps use it via `lib/theme/app_theme.dart`. If you want fully offline/air-gapped, bundle the Inter .ttf and switch to a local `TextTheme`.
12. **(v2) Shared design system lives in `docs/DESIGN_SPEC.md`** and is implemented identically in both apps under `lib/theme/` (`app_colors`, `app_spacing`, `app_theme`) + shared `lib/widgets/` components (AppCard, StatusChip, StatTile, AppButton, EmptyState/LoadingState/ErrorState, AppAvatar…). Seed color `#4F46E5`, Material 3, light+dark. Keep BOTH apps in sync if you change tokens.

## 5. How to run (quick reference)

```bash
# backend (MongoDB must be up)
cd backend && npm install && npm run seed && npm start   # → localhost:5000/api/v1

# admin panel
cd admin_panel && flutter pub get && flutter run -d chrome   # login: admin@company.com/Admin@123

# mobile app
cd mobile_app && flutter pub get && flutter run              # login: emp1@company.com/Employee@123

# checks
cd backend && npm run seed                    # reset DB to pristine
cd mobile_app && flutter analyze && flutter test
cd admin_panel && flutter analyze && flutter build web --release
```

Demo flow: admin panel → Office Settings (geofence) → QR Display page (kiosk) → mobile app scans it → Live Attendance/Dashboard update → Reports export xlsx.

## 6. Architecture map (where things live)

- `backend/src/`: `server.js` (entry, port-fallback logic) · `app.js` · `config/` · `models/` (User, Department, Designation, Attendance, OfficeSettings, AttendanceRequest, Document) · `middleware/` (auth, role guard, error handler, multer) · `controllers/` + `routes/` (one pair per resource) · `utils/` (qr crypto, haversine, time helpers, excel, envelope) · `seed/seed.js`. Uploads → `backend/uploads/` (10MB, pdf/jpg/jpeg/png).
- `mobile_app/lib/`: `config/api_config.dart` · `models/` (null-tolerant fromJson, contract-shaped) · `services/api_client.dart` (Bearer inject via flutter_secure_storage, typed ApiException) + location service (full permission handling) · `providers/` (auth, attendance, profile/documents) · `screens/` (splash→login→home w/ ticking today card + 4 state-gated actions, scanner flow, history, monthly summary, requests, profile, documents). Tests: 18 model round-trip tests.
- `admin_panel/lib/`: same layered shape; `services/file_download.dart` (web Blob save); screens = shell w/ NavigationRail → Dashboard (stat cards + fl_chart trends), Live Attendance (30s auto-refresh), Logs (+Correct dialog, +Manual entry), Requests (tabs), Missing Check-outs, Employees (CRUD + xlsx import/export), Departments/Designations, Office Settings, QR Display (auto-refresh kiosk), Reports (6 types + xlsx export).

## 7. User context & preferences

- User: Shamil (afrazdigital@gmail.com), project "1NexCrew". Communicates in informal English; prefers the agent to act autonomously and keep this folder updated so context is never lost.
- **Standing instruction (2026-07-07):** maintain `agent_docs/` exactly per the folder rules at the top of this file. This was explicit and emphatic — treat as permanent.
- Model/session note: user runs claude-fable-5; heavy multi-agent workflow was used for the initial build (ultracode was on for that turn, later off — default to normal tooling unless re-enabled).

## 8. Update log

- **2026-07-07** — Project bootstrapped from `docs/PLAN.md`. Authored `docs/API_CONTRACT.md`; launched 3-builder workflow (`wf_ba04ad97-10a`). Backend build DONE (self-tested, port-5000/AirPlay workaround). Mobile build DONE + verification PASSED (0 analyze issues, 18/18 tests; geolocator pinned ^13, see Gotcha 2). Root README written. Stray root `build/` deleted. Created `agent_docs/` + this file.
- **2026-07-07 (end of day)** — Workflow `wf_ba04ad97-10a` COMPLETED: **backend PASSED, mobile_app PASSED, admin_panel PASSED — all with 0 fix rounds, 0 open issues.** Backend verified end-to-end against live MongoDB (full contract, adversarial checks incl. stale-QR 403, geofence distance message, double check-in/out 409s, import/export round-trip with per-row errors, document ownership, byte-identical downloads). Admin panel: analyze clean, 3/3 tests, release web build succeeded, endpoint-by-endpoint contract match confirmed. Added §3 "interpretation choices" and Gotchas 9–10 from verifier findings. Status: system COMPLETE and verified; no processes left running; DB re-seeded pristine. Note: initial build turn ran with ultracode ON; it is now OFF — use normal single-agent tooling unless user re-enables.
- **2026-07-08** — **v2 SHIPPED & VERIFIED.** User requested: remove breaks, single Check-In/Check-Out button, permanent (regenerate-only) QR, full modern redesign of both Flutter apps. Main agent edited `docs/API_CONTRACT.md` to v2 (added a "Revision note (2026-07-08 — v2)") and wrote `docs/DESIGN_SPEC.md` (shared design system, seed `#4F46E5`, Inter, light+dark). 3 parallel Agent subagents (one per app) implemented it; main agent then INDEPENDENTLY verified: backend 17/17 v2 smoke checks (permanent QR stable + regenerate invalidates old, no break/onBreak/qrRefreshSeconds fields, geofence intact), mobile analyze clean + 18/18 tests, admin analyze clean + 3/3 tests + release web build OK, repo-wide grep clean. Backend added `models/QrConfig.js` + `POST /qr/regenerate`; both Flutter apps gained `lib/theme/` + shared `lib/widgets/`. Updated §2/§3/§4 of this file to v2. No processes left running; DB pristine. **Still not done: real human/device demo of the new build (top of §2 NEXT STEPS).**
