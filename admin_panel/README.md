# Attendance Admin Panel (Flutter Web)

The administrator web panel of the Employee Attendance Management System.
It talks to the Node.js backend described in `../docs/API_CONTRACT.md`.

## Features

- **Dashboard** — stat cards (employees, present/absent/late, on leave, on
  break, checked out, average work hours, attendance rate) and a
  daily/weekly/monthly attendance trends chart (present = green, late =
  orange, absent = red).
- **Live Attendance** — auto-refreshing (every 30 s) board of all active
  employees with summary chips and a department filter.
- **Attendance Logs** — filterable, paginated log table with admin
  *Correct* action (check-in/out, status + required note) and *Manual
  Entry* (including marking ON_LEAVE days).
- **Requests** — pending/approved/rejected regularization requests with
  approve/reject + optional review note.
- **Missing Check-outs** — pick a date (defaults to yesterday) and resolve
  records that were never checked out.
- **Employees** — searchable, paginated table with department/designation/
  active filters, add/edit dialogs, soft delete, Excel import (`.xlsx`) with
  per-row error reporting, and Excel export.
- **Departments & Designations** — simple CRUD lists; deleting an item that
  is still in use surfaces the server's 409 conflict nicely.
- **Office Settings** — geofence (latitude/longitude/radius), working
  hours, tolerances, QR refresh interval and timezone.
- **QR Display** — kiosk page rendering the rotating encrypted QR code with
  a countdown ring; point a wall-mounted screen at this section.
- **Reports** — daily/weekly/monthly attendance, working hours, late
  arrivals and early check-outs, each with JSON preview and Excel export.
  All durations are displayed as `h:mm`.

## Prerequisites

- Flutter 3.44+ (stable) with web support enabled
- The backend running at `http://localhost:5000` (see `../backend/README.md`)
- MongoDB running locally and seeded (`npm run seed` inside `../backend`)

## Run

```bash
cd admin_panel
flutter pub get
flutter run -d chrome
```

The API base URL is `http://localhost:5000/api/v1`, configured in
`lib/config/api_config.dart`.

## Default admin credentials (from the backend seed)

| Field    | Value               |
|----------|---------------------|
| Email    | `admin@company.com` |
| Password | `Admin@123`         |

Employee accounts (e.g. `emp1@company.com` / `Employee@123`) are rejected by
this panel — it is admin-only.

## Build for production

```bash
flutter build web --release
```

The deployable bundle lands in `build/web/`.

## Tests & analysis

```bash
flutter analyze
flutter test
```

## Project layout

```
lib/
  config/       api_config.dart (base URL), app_colors.dart (status palette)
  models/       contract objects (null-tolerant fromJson)
  services/     api_client.dart (JWT, envelope decoding, multipart, downloads)
                file_download.dart (browser Blob download via package:web)
  providers/    one ChangeNotifier per section
  screens/      login, shell (navigation rail) and the 10 sections
  widgets/      status chips, stat cards, pickers, pagination, tables
```
