# NexCrew Attendance

QR + geofence based attendance tracking. Two front-ends — **NexCrew Attendance** (employees) and **NexCrew Admin** (administrators) — over a Node.js/Express/MongoDB backend. Both front-ends ship as Flutter Web; the employee app also builds as an Android/iOS app.

| Directory | What it is |
|---|---|
| [`backend/`](backend/) | REST API — Node.js (Express) + MongoDB (Mongoose), JWT auth, encrypted permanent QR, geofencing, Excel import/export |
| [`mobile_app/`](mobile_app/) | **NexCrew Attendance** — employee app: geofence pre-flight, scan QR to check in/out, activity history + monthly summary, requests, profile, documents |
| [`admin_panel/`](admin_panel/) | **NexCrew Admin** — overview, attendance (live/logs/missing check-outs), requests, people, office settings, QR + kiosk, reports |
| [`tools/generate_icons.py`](tools/generate_icons.py) | Regenerates every app icon for both apps from code |
| [`docs/PLAN.md`](docs/PLAN.md) | Product requirements |
| [`docs/API_CONTRACT.md`](docs/API_CONTRACT.md) | The REST API contract all three apps follow |
| [`docs/DESIGN_SPEC.md`](docs/DESIGN_SPEC.md) | Shared design system + information architecture |

## Branding

| | Employee app | Admin panel |
|---|---|---|
| Name | NexCrew Attendance | NexCrew Admin |
| Short name | NexCrew | NexCrew Admin |
| Icon | fingerprint on indigo `#6366F1 → #4338CA` | fingerprint on navy-indigo `#0F172A → #3730A3` |

Icons are generated, not hand-drawn — edit the palette or glyph in [`tools/generate_icons.py`](tools/generate_icons.py) and re-run it to restyle all 30 files at once. The Dart package names (`attendance_admin`, `attendance_mobile`) and the Android `applicationId` (`com.nexcrew.attendance_mobile`) are deliberately unchanged: they are identifiers, and changing the applicationId would make an update install as a separate app.

## Quick start

Prerequisites: Node.js ≥ 20, Flutter ≥ 3.24, MongoDB running locally (`mongod`).

### 1. Backend

```bash
cd backend
npm install
npm run seed     # creates admin, office settings, departments, sample employees
npm start        # http://localhost:5000/api/v1
```

### 2. Admin panel (Flutter Web)

```bash
cd admin_panel
flutter pub get
flutter run -d chrome
```

Log in as **admin@company.com / Admin@123**. Configure the office location & geofence radius under *Office Settings*, then open the *QR Display* page — this is the rotating QR code employees scan (run it on a screen at the office entrance).

### 3. Mobile app (employees)

```bash
cd mobile_app
flutter pub get
flutter run      # on a device/emulator
```

Log in as **emp1@company.com / Employee@123** (…through emp8). On an Android emulator, change the API base URL in `lib/config/api_config.dart` from `localhost` to `10.0.2.2`. On a physical device, use your machine's LAN IP.

## How attendance works

1. The admin panel displays an **encrypted QR code** (AES-256-GCM) that rotates every ~30 s.
2. An employee picks an action (check in / check out / start break / end break) and scans the QR; the app captures their **GPS location**.
3. The server validates the QR's authenticity and freshness, verifies the employee is **inside the configured geofence radius**, and enforces the attendance state machine (no double check-ins, breaks must be open to close, etc.).
4. Working hours, break duration, late-arrival and early-checkout flags are computed server-side; admins see it live and can correct records (with an audit note), approve regularization requests, and export Excel reports.

## Seeded logins

| Role | Email | Password |
|---|---|---|
| Admin | admin@company.com | Admin@123 |
| Employees | emp1@company.com … emp8@company.com | Employee@123 |

Default office: lat `25.1972`, lng `55.2744`, radius `150 m`, hours `09:00–18:00` (`Asia/Dubai`) — change it in the admin panel.
