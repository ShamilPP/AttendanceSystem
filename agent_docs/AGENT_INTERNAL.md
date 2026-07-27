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

## 2. Current status — v3 UX/IA REWORK COMPLETE (2026-07-27)

**v3 is client-side only. Backend and `docs/API_CONTRACT.md` are UNCHANGED — do not "sync" them; nothing moved.** User's brief: "ui and workflow is bad… analyse everything how can make it better." Analysis found the visual layer was fine (the v2 design system holds up); the real defects were **information architecture and workflow**. Full scope approved, both new deps approved.

| Area | What changed | Why (do not undo without reading this) |
|---|---|---|
| **Admin routing** | `go_router` (14.8.1) + `lib/router/app_router.dart`. Every section has a URL; `ShellRoute` builds the shell **once**. | It's a *web* app that had `int _index` state: no back button, no bookmarks, no deep links, and every nav switch rebuilt the outgoing screen, dumping its filters + scroll. |
| **Admin nav** | 10 flat items → **5 daily** (Overview, Attendance, Requests, People, Reports) + **2 setup** (QR code, Settings), with live badges. | Live/Logs/Missing were 4 separate top-level items showing the same data at different time horizons. "Departments" was also mislabelled — it opened a screen containing departments *and* designations. |
| **Admin dashboard** | "Needs your attention" card (pending requests + missing check-outs, with action buttons) at the top; **every headcount tile drills into the filtered live board**; silent 60s auto-refresh. | Stat tiles had no `onTap`: "Absent: 5" never said *who*. The two queues an admin must act on daily were invisible until you navigated to them. |
| **Kiosk** | New `/kiosk` route **outside** the shell; Regenerate is hidden there. | It's left running on a lobby display — a stray click must never invalidate everyone's QR. |
| **Mobile pre-flight** | `PresenceProvider` + Home strip: resolves the geofence *before* the camera opens ("You're at the office" / "240 m away"). | The old flow asked for GPS **after** the QR was scanned — 5 steps to learn a 403 that was knowable at step 0. |
| **Mobile permission timing** | First Home load checks **silently** (`askPermission: false`); the OS dialog only ever fires from a deliberate tap. | Permission was requested mid-scan, the worst possible moment; a denial stranded the user with no path forward. |
| **Mobile reminders** | `flutter_local_notifications` + `NotificationService`, times driven by office settings, toggle in Profile. | **The admin's entire "Missing check-outs" screen is a symptom of nobody being reminded.** This attacks the source. |
| **Mobile nav** | History + Summary merged into one **Activity** tab; context-aware scan FAB (suppressed on Home). | Summary had *two* entry points on Home and none in the nav, while History — the same data — was a tab. |
| **Mobile recovery** | History detail sheet → "Request a correction" (date pre-filled). Unsent-scan card on Home. | There was zero link from history to the requests flow. |

### ⚠️ Design decision worth preserving: NO silent scan replay

The obvious "offline queue" is **wrong here and was deliberately rejected**. `POST /attendance/scan` timestamps on *receipt*, so replaying a queued 09:04 check-in at 11:00 files it at 11:00 — worse than losing it, because it looks correct. Instead `PendingScanService` records the attempt (connectivity failures only, `statusCode == 0` — never a server *rejection* like bad QR/geofence/wrong state, which already has an answer) and Home offers to convert it into a regularization request pre-filled with the real scan time. That path takes an explicit timestamp and goes through admin review, which is exactly what a disputed time should do. Entries self-expire after 24h.

### ⚠️ The two haversines must stay identical

`PresenceProvider.distanceMetersBetween` mirrors `backend/src/utils/geo.js` exactly (same formula, R = 6371000). **Verified identical on 2026-07-27.** If they drift, the app tells employees they're inside a fence the server rejects. `mobile_app/test/presence_test.dart` guards the client side.

The pre-flight is a **hint, never a gate** — the action button stays enabled regardless of what it says. GPS drift must not lock somebody out of their own attendance; the server is the only authority.

**v3 verification (2026-07-27):** admin `flutter analyze` clean + 3/3 tests + `flutter build web --release` OK; mobile `flutter analyze` clean + **27/27** tests (was 18; +9 new in `presence_test.dart`) + `flutter build web --release` OK.

**v3 NOT done / follow-ups:**
1. **Still never demoed on a real device or in a real browser** (this predates v3 — machine-verified only). v3 raises the stakes: the presence strip, the notification toggle and the FAB have never been seen running.
2. `flutter_local_notifications` has **no web implementation**. The employee app is deployed as Flutter *web* (§2c), so on that build `NotificationService.init()` throws, is caught, and `_available` stays false → the toggle reports "blocked". Intentional and safe, but it means **reminders only work on the APK**, not the hosted staff app. If reminders matter on web, that needs the Web Notifications API or server push.
3. Android exact-alarm/battery-saver restrictions can silently drop reminders; `AndroidScheduleMode.inexactAllowWhileIdle` is used to stay permission-light.
4. ~~`deploy-web.sh` bundles are stale~~ — refreshed in v3.1 (§2d).

## 2b. Previous status — v2 COMPLETE & VERIFIED (2026-07-08)

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

## 2c. Deployment — Hostinger VPS (IN PROGRESS, 2026-07-08)

Deploying to a Hostinger VPS. Facts:
- Host `srv1497924`, user `shamildevv`, Ubuntu (Node v20.19.4). Repo cloned to `~/AttendanceSystem` (from GitHub `ShamilPP/AttendanceSystem`).
- **Database: MongoDB Atlas** (NOT local mongod). Cluster `testcluster.cz73g95.mongodb.net`, db `AttendanceSystem`, user `shamilpp4115`. Connection string lives in `backend/.env` only. **TODO/security:** rotate the Atlas password (it leaked into a chat paste) and restrict Atlas Network Access to the VPS IP.
- **Backend runs under PM2**, process name `attendance-api-5100`, **PORT=5100** (5000/5001 were already taken by other `nexbilling` apps). `pm2 save` done; `pm2 startup` (boot persistence) command was issued. Verified: `GET /health` ok + admin login returns token on `localhost:5100`.
- Ports already in use on the box: 5000, 5001 (nexbilling node), 4000, 3000/3001/3002 (next-server), 3006. **nginx** already serving 80/443 for other sites. So our API sits on 5100 behind nginx.
- **Planned architecture (single subdomain):** one subdomain (e.g. `attendance.<domain>`); nginx routes `/api/` → `localhost:5100`, everything else → admin panel static build (`flutter build web`). Same-origin avoids mixed-content/CORS. Admin panel built with baseUrl = full `https://<subdomain>/api/v1`. Mobile APK uses the same URL.
- **Frontend hosting decision:** BOTH admin panel AND employee app are hosted as **Flutter web** apps (user chose web for the client too). Employee app was Android/iOS-only; `flutter create --platforms=web .` added `mobile_app/web/` and it now compiles for web (⚠️ caveat: camera/GPS/file-upload on web are unverified at runtime — needs HTTPS + real-browser testing; `dart:io` multipart compiles via http package's conditional imports but web upload may need a bytes-based path).
- **API base URL is now build-time configurable:** both apps' `lib/config/api_config.dart` read `String.fromEnvironment('API_BASE_URL')` (getter `baseUrl`), default = `http://localhost:5000/api/v1` for dev. Production web builds pass `--dart-define=API_BASE_URL=/api/v1` (relative → same-origin, nginx proxies `/api/`). APK would pass the absolute `https://<domain>/api/v1`.
- **Build script:** `deploy-web.sh [admin|staff|both]` at repo root — builds with the prod define and publishes to top-level `build/admin` and `build/staff` (outside each flutter project). No pm2 (user restarts manually). Both bundles currently built on the Mac (41 MB each, base href `/`).
- **Planned per-subdomain nginx:** each subdomain serves its static bundle at root AND proxies `location /api/` → `http://127.0.0.1:5100/` → same-origin, no CORS. Recommended: `attendance.<domain>` = employee (build/staff), `admin.<domain>` = admin (build/admin).
- **PENDING:** (Part 2) get the domain from user + DNS A records → nginx server blocks + certbot SSL; (Part 3) upload `build/admin` + `build/staff` to VPS `/var/www/...` (build on Mac + rsync, OR install Flutter on VPS and run `deploy-web.sh` there). Still waiting on the domain/subdomain names.

## 2d. Branding (v3.1, 2026-07-27)

Both front-ends were still shipping Flutter stock defaults ("attendance_admin", "A new Flutter project", Flutter-blue `#0175C2`, and the **same default Flutter logo in both apps**). Now branded:

| | Employee app (`mobile_app/`) | Admin panel (`admin_panel/`) |
|---|---|---|
| Name | **NexCrew Attendance** | **NexCrew Admin** |
| PWA short_name | NexCrew | NexCrew Admin |
| theme_color / background | `#4F46E5` / `#4F46E5` | `#312E81` / `#0F172A` |
| Icon gradient | `#6366F1 → #4338CA` | `#0F172A → #3730A3` |

- **Icons are generated from code — never hand-edit the PNGs.** `tools/generate_icons.py` writes all **30** files (web favicon + 4 PWA icons per app, 5 Android mipmap densities, 15 iOS AppIcon slots). Usage is in its docstring; re-run it from the repo root after changing `PALETTES` / `RIDGES`.
- Mark = fingerprint, deliberately matching `Icons.fingerprint` already used in-app (admin rail brand, login `_BrandMark`, QR kiosk). Both apps share the shape and differ only by gradient.
- **Why a `small` glyph variant exists:** the 5-ridge fingerprint turns to mush below ~48px. Favicons (32px) and the tiny iOS slots (≤60px) use a 3-ridge, thicker-stroke version — same silhouette, legible small. Verified by eye at 32px.
- Rasterising uses **headless Chrome + `sips`** because this Mac has no ImageMagick, Pillow, cairosvg or rsvg. Note Chrome's `--screenshot` **crops rather than scales** when the window is smaller than the SVG — so every size is downsampled from a 1024px master, never rendered directly. (Getting this wrong produced a zoomed corner instead of an icon.)
- **Deliberately NOT renamed** (identifiers, not user-visible): Dart package names `attendance_admin` / `attendance_mobile` (used in `package:` imports across the tests), the admin token key `attendance_admin_token` (renaming logs everyone out), and Android `applicationId` `com.nexcrew.attendance_mobile` (**changing it makes an update install as a separate app**).
- Known caveat: generated PNGs keep an alpha channel — fine for web/Android, but the App Store rejects alpha in iOS icons. Flatten before any iOS submission.
- `deploy-web.sh both` was re-run, so `build/admin` and `build/staff` now carry the new branding.

## 2e. Layout/design fixes (v3.2, 2026-07-27)

User sent a screenshot of Office settings: *"very bad design… every screen"*. Root causes were **layout defects, not styling**:

| Defect | Fix |
|---|---|
| Every input wrapped in `Expanded` → "09:00" in a 285pt box, timezone spanning 712pt | `SettingRow` (label left, control right, content-sized) + `FormRow` for paired dialog fields |
| `Row` centres children, so a field with `helperText` beside one without floated out of line (visible on Radius, and identically in the employee dialog) | Both widgets force `crossAxisAlignment.start` |
| Content sliced mid-glyph where the scroll clipped under the fixed header | `FadingScrollView`, applied by `PageScaffold` to **every** screen (`fadeScroll: false` to opt out) |
| "Geofence preview" read `widget.initial`, so editing radius never moved it — a lying control | Bound to live controller values; ring scales logarithmically (10 m–2 km) |
| Save buried at the bottom of a tall card | Pinned save bar, appears only when dirty, with Discard |
| Dark mode: `outlineVariant` borders made fields dissolve; `SegmentedButton` unselected segment rendered white | `fieldBorder` (= `outline` @55% in dark) + explicit `segmentedButtonTheme`; **both apps** |
| `formatMinutes` used for a duration → "A 9:00 working day" reads as a clock time | Explicit `9h 0m` |

**⚠️ Two refactors that unblock testing — do not undo:**
1. **`Routes` moved to `lib/router/routes.dart`**, import-free. It used to live in `app_router.dart`, which imports every screen, so any screen importing `Routes` transitively pulled in *all* of them.
2. **`file_download.dart` is now a conditional-export facade** (`file_download_web.dart` / `file_download_stub.dart`). It imports `dart:js_interop`, which does not exist in the VM, so anything touching Employees/Reports was impossible to compile under `flutter test`.

**Screenshot harness (`test/screenshots_test.dart`)** — renders screens to `test/goldens/*.png` with stubbed providers (admin providers have public mutable fields, so no network is needed):
```bash
cd admin_panel && flutter test --tags screenshots --update-goldens
```
Skipped by default via `dart_test.yaml`. Caveats: needs macOS system fonts; google_fonts cannot fetch Inter offline so the harness substitutes a system face (real theme otherwise) and logs noisy "unable to load font" errors — harmless. **Use this before claiming any UI work looks right** — six screens were verified this way, which is how the white segmented button and the clock-time duration were caught.

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
13. **(v3) Admin sub-screens must NOT add their own page padding.** `LiveAttendanceScreen`, `AttendanceLogsScreen`, `MissingCheckoutsScreen`, `EmployeesScreen` and `CatalogScreen` are rendered *inside* `PageScaffold` (via `AttendanceScreen` / `PeopleScreen`), which supplies padding and the title. Each has a `// Page padding/title come from the enclosing PageScaffold.` comment where its old `Padding` wrapper was. Re-adding one double-pads the page.
14. **(v3) `AttentionProvider` polls every 2 min and is started by the shell, stopped in `ShellScreen.dispose()`** (the shell only unmounts on logout) — otherwise its timer keeps firing 401s against a cleared token. A failed poll deliberately keeps the last known badge value rather than flashing a misleading 0.
15. **(v3) The live board's status filter is client-side.** `GET /attendance/live` has no status parameter; `LiveAttendanceProvider.visibleRecords` filters the fetched rows. Read `visibleRecords`, not `data.records`, when rendering the table.
16. **(v3) go_router + provider wiring:** `AuthProvider` is constructed in `_AdminAppState` (**above** the router) because the router both redirects on it and uses it as `refreshListenable`; it is then injected with `ChangeNotifierProvider.value`. Don't move it back into the `MultiProvider` create list — the router is built from it.
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
- `mobile_app/lib/`: `config/api_config.dart` · `models/` (null-tolerant fromJson, contract-shaped; **v3** `office_settings.dart`) · `services/` — `api_client.dart` (Bearer via flutter_secure_storage, typed ApiException), `location_service.dart`, **v3** `notification_service.dart` (daily reminders) + `pending_scan_service.dart` (unsent-scan recovery) · `providers/` (auth, attendance, documents, **v3** `presence_provider.dart`) · `widgets/` (+**v3** `attendance_success_sheet.dart`, shared by Home and the shell FAB) · `screens/`: splash→login→`home_shell` (Home · **Activity** · Requests · Profile + context-aware scan FAB) — `home_tab` (pending-scan card, presence strip, status card, hero button), `activity_tab` (hosts `HistoryView` + `SummaryView` as tabs), scanner, requests, profile (reminders toggle), documents. **Tests: 27** (`models_test.dart` 18 + `presence_test.dart` 9).
- `admin_panel/lib/`: same layered shape; `services/file_download.dart` (web Blob save); **v3** `router/app_router.dart` (all routes + auth redirect), `providers/attention_provider.dart` (badge counts), `widgets/page_scaffold.dart` (page header + URL sub-tabs) + `widgets/skeleton.dart`. Screens: `shell_screen` (grouped rail, badges) wrapping → `dashboard_screen` (attention card + drill-down tiles + fl_chart trends), `attendance_screen` (tab host → live/logs/missing), `requests_screen`, `people_screen` (tab host → employees/catalog), `reports_screen`, `qr_display_screen`, `office_settings_screen`; `kiosk_screen` sits **outside** the shell.

## 7. User context & preferences

- User: Shamil (afrazdigital@gmail.com), project "1NexCrew". Communicates in informal English; prefers the agent to act autonomously and keep this folder updated so context is never lost.
- **Standing instruction (2026-07-07):** maintain `agent_docs/` exactly per the folder rules at the top of this file. This was explicit and emphatic — treat as permanent.
- Model/session note: user runs claude-fable-5; heavy multi-agent workflow was used for the initial build (ultracode was on for that turn, later off — default to normal tooling unless re-enabled).

## 8. Update log

- **2026-07-27 (latest)** — **v3.2 LAYOUT FIXES.** User screenshotted Office settings: "very bad design… every screen". Diagnosed as layout defects rather than styling (see §2e): every input `Expanded` to absurd widths, `Row`s centring mismatched-height fields, scroll content sliced under the fixed header, a geofence "preview" bound to saved instead of edited values, save buried at the bottom, and two dark-mode theme bugs. Added `SettingRow`/`SettingsCard`, `FormRow`, `FadingScrollView`, `NumberField`; rebuilt `office_settings_screen.dart`; converted the employee + attendance-log dialogs to `FormRow`; themed `fieldBorder` and `segmentedButtonTheme` in **both** apps. Extracted `Routes` to `router/routes.dart` and made `file_download.dart` a conditional-export facade — both were blocking any widget test that touched a screen. Built a **screenshot harness** and used it to review six screens; it caught the white `SegmentedButton` and the "A 9:00 working day" copy bug that code review had missed. Verified: both apps analyze clean, admin 3/3 (+screenshots skipped) and mobile 27/27 tests, both web release builds OK, `deploy-web.sh both` re-run. **Not verified visually: the mobile app's screens** (harness is admin-only so far) and the admin dialogs/light mode.

- **2026-07-27 (later)** — **v3.1 BRANDING.** User: "this both apps is web, app name, web name, icon, update everything." Both apps were still 100% Flutter stock (same default Flutter logo in both, "A new Flutter project", `#0175C2`). Named them **NexCrew Attendance** / **NexCrew Admin** across web `index.html` (title, description, `theme-color`, apple-touch title), both `manifest.json` (name/short_name/description/theme+background colors), Android `android:label`, iOS `CFBundleDisplayName`/`CFBundleName`, the mobile `MaterialApp.title`, and both pubspec descriptions. Wrote `tools/generate_icons.py` (fingerprint mark, per-app gradients, `small` variant for favicon legibility) and generated **30** icons across web/Android/iOS. Root README rebranded and de-staled (it still described breaks + a *rotating* QR, both gone since v2). Verified: both apps analyze clean, admin 3/3 + mobile 27/27 tests, both `flutter build web --release` OK, built `index.html`/`manifest.json` carry the new names, admin & staff favicons differ. `./deploy-web.sh both` re-run → `build/admin` + `build/staff` refreshed (clears the v3 "bundles are stale" follow-up). See §2d for what was deliberately NOT renamed.

- **2026-07-27** — **v3 UX/IA REWORK SHIPPED.** User: "ui and workflow is bad… first analyse everything how can make it better." Analysis concluded the *visual* layer was already sound (v2 design system) and the real problems were IA + workflow; presented that honestly rather than restyling. User approved full scope (both apps) and both new deps. Delivered: admin `go_router` URL routing + `ShellRoute` (fixes no-back-button/no-deep-links/state-loss on a **web** app), nav 10 items → 5+2 with live badges, actionable dashboard ("Needs your attention" card + drill-down stat tiles + silent 60s refresh), `/kiosk` outside the shell, `PageScaffold`/skeleton polish; mobile geofence **pre-flight** before the camera opens, permission moved out of mid-scan, local check-out reminders (attacks the Missing-check-outs queue at source), History+Summary merged into **Activity**, context-aware scan FAB, history→correction link, and unsent-scan recovery via regularization (**deliberately not** a replay queue — see §2). Deps added: admin `go_router`; mobile `flutter_local_notifications` + `timezone` + `shared_preferences`, plus `POST_NOTIFICATIONS`/`RECEIVE_BOOT_COMPLETED` in AndroidManifest. **Backend + API_CONTRACT untouched.** Verified: both apps analyze clean, admin 3/3 tests + web release build, mobile 27/27 tests + web release build; client haversine confirmed byte-identical in behaviour to `backend/src/utils/geo.js`. Updated `docs/DESIGN_SPEC.md` (new "Navigation & information architecture" section + rewritten screen directions) and §2/§4/§6 here. New gotchas 13–16. **Still not done: real device/browser demo (now the top follow-up), and reminders do not work on the Flutter-web staff build (§2 item 2).**

- **2026-07-07** — Project bootstrapped from `docs/PLAN.md`. Authored `docs/API_CONTRACT.md`; launched 3-builder workflow (`wf_ba04ad97-10a`). Backend build DONE (self-tested, port-5000/AirPlay workaround). Mobile build DONE + verification PASSED (0 analyze issues, 18/18 tests; geolocator pinned ^13, see Gotcha 2). Root README written. Stray root `build/` deleted. Created `agent_docs/` + this file.
- **2026-07-07 (end of day)** — Workflow `wf_ba04ad97-10a` COMPLETED: **backend PASSED, mobile_app PASSED, admin_panel PASSED — all with 0 fix rounds, 0 open issues.** Backend verified end-to-end against live MongoDB (full contract, adversarial checks incl. stale-QR 403, geofence distance message, double check-in/out 409s, import/export round-trip with per-row errors, document ownership, byte-identical downloads). Admin panel: analyze clean, 3/3 tests, release web build succeeded, endpoint-by-endpoint contract match confirmed. Added §3 "interpretation choices" and Gotchas 9–10 from verifier findings. Status: system COMPLETE and verified; no processes left running; DB re-seeded pristine. Note: initial build turn ran with ultracode ON; it is now OFF — use normal single-agent tooling unless user re-enables.
- **2026-07-08** — **v2 SHIPPED & VERIFIED.** User requested: remove breaks, single Check-In/Check-Out button, permanent (regenerate-only) QR, full modern redesign of both Flutter apps. Main agent edited `docs/API_CONTRACT.md` to v2 (added a "Revision note (2026-07-08 — v2)") and wrote `docs/DESIGN_SPEC.md` (shared design system, seed `#4F46E5`, Inter, light+dark). 3 parallel Agent subagents (one per app) implemented it; main agent then INDEPENDENTLY verified: backend 17/17 v2 smoke checks (permanent QR stable + regenerate invalidates old, no break/onBreak/qrRefreshSeconds fields, geofence intact), mobile analyze clean + 18/18 tests, admin analyze clean + 3/3 tests + release web build OK, repo-wide grep clean. Backend added `models/QrConfig.js` + `POST /qr/regenerate`; both Flutter apps gained `lib/theme/` + shared `lib/widgets/`. Updated §2/§3/§4 of this file to v2. No processes left running; DB pristine. **Still not done: real human/device demo of the new build (top of §2 NEXT STEPS).**
