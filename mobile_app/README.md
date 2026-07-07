# Attendance Mobile (Employee App)

Flutter app for employees of the Attendance Management System. Employees sign
in with their company account, mark attendance by scanning the office QR code
(with GPS geofence verification), browse their history and monthly summaries,
submit regularization requests, and manage their documents.

Targets **Android** and **iOS**. Built with Material 3, `provider` state
management, and the REST API defined in [`../docs/API_CONTRACT.md`](../docs/API_CONTRACT.md).

## Features

- **Login** — email + password, JWT stored in secure storage
  (`flutter_secure_storage`); session restored on app start.
- **Home** — live "today" card (check-in/out, break state, ticking worked
  duration) and four actions: Check In, Check Out, Start Break, End Break.
  Buttons enable/disable based on `GET /attendance/today`.
- **QR scan flow** — each action opens the camera (`mobile_scanner`); on
  detection the app fetches GPS (`geolocator`) and calls
  `POST /attendance/scan`. Server-side QR, geofence, and state errors are
  shown verbatim, with retry.
- **History** — paginated, newest first, date-range filter, per-day detail
  with breaks and correction notes.
- **Monthly summary** — `GET /attendance/summary?month=YYYY-MM`, stat tiles
  for present/late/absent/leave days, work/break hours.
- **Requests** — list own regularization requests with status filter; create
  new ones (missed check-in/out, full day, leave).
- **Profile** — employee info, change password, logout.
- **Documents** — list/upload/download/delete own documents
  (PDF/JPG/PNG, max 10 MB).

## Prerequisites

- Flutter 3.44+ (stable)
- The backend running (see `../backend/`): `npm run dev` — it listens on
  `http://localhost:5000/api/v1`
- Seeded data (`npm run seed` in the backend) gives you a sample employee
  login: `emp1@company.com` / `Employee@123`

## Setup

```bash
cd mobile_app
flutter pub get
flutter run          # pick a connected device / emulator
```

## Pointing the app at the backend

The base URL is a compile-time constant in
[`lib/config/api_config.dart`](lib/config/api_config.dart):

```dart
static const String baseUrl = 'http://localhost:5000/api/v1';
```

Adjust it for your setup:

| Where the app runs      | Base URL to use                            |
|-------------------------|--------------------------------------------|
| iOS simulator           | `http://localhost:5000/api/v1` (default)   |
| **Android emulator**    | `http://10.0.2.2:5000/api/v1`              |
| Physical device (LAN)   | `http://<your-machine-LAN-IP>:5000/api/v1` |

For physical devices, the phone and your machine must be on the same network
and the backend must be reachable on that interface.

> HTTP (cleartext) is allowed for development:
> `android:usesCleartextTraffic="true"` in the Android manifest and
> `NSAllowsArbitraryLoads` in the iOS `Info.plist`. Remove both and use HTTPS
> in production.

## Permissions

| Permission | Why | Where declared |
|---|---|---|
| Internet | API calls | `android/app/src/main/AndroidManifest.xml` |
| Camera | QR scanning | Android manifest + `NSCameraUsageDescription` (iOS) |
| Location (fine, when-in-use) | Geofence check on every scan | Android manifest + `NSLocationWhenInUseUsageDescription` (iOS) |
| Photo library (iOS) | Uploading document photos | `NSPhotoLibraryUsageDescription` |

Camera and location permissions are requested at first use. If location is
permanently denied or GPS is off, the scan screen explains what to do and
offers a shortcut to settings. Android `minSdk` is 23 (required by
`mobile_scanner`).

## Project structure

```
lib/
  config/       api_config.dart — base URL + timeouts
  models/       user, attendance, attendance_summary,
                attendance_request, document (contract-exact fromJson/toJson)
  services/     api_client.dart — Bearer-token HTTP wrapper, envelope
                decoding, typed ApiException, multipart upload/download
                location_service.dart — GPS + permission handling
  providers/    auth, attendance (today/scan/history/summary/requests),
                documents (ChangeNotifier + provider)
  screens/      splash, login, home shell + tabs, scan, summary,
                new request, documents
  widgets/      status chips, stat tiles, loading/error/empty states
  utils/        date/duration/bytes formatters
```

## Tests

Model round-trip tests using contract-shaped JSON fixtures:

```bash
flutter test
```

## Static analysis

```bash
flutter analyze
```
