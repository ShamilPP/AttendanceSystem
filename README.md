# Employee Attendance Management System

QR + geofence based attendance tracking with a Flutter employee app, a Flutter Web admin panel, and a Node.js/Express/MongoDB backend.

| Directory | What it is |
|---|---|
| [`backend/`](backend/) | REST API — Node.js (Express) + MongoDB (Mongoose), JWT auth, encrypted rotating QR, geofencing, Excel import/export |
| [`mobile_app/`](mobile_app/) | Flutter app for employees — scan QR to check in/out & manage breaks, history, monthly summary, requests, profile, documents |
| [`admin_panel/`](admin_panel/) | Flutter Web panel for admins — dashboard, live attendance, corrections, employees, office/geofence settings, QR display, reports |
| [`docs/PLAN.md`](docs/PLAN.md) | Product requirements |
| [`docs/API_CONTRACT.md`](docs/API_CONTRACT.md) | The REST API contract all three apps follow |

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
