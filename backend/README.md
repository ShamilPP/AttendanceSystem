# Attendance System — Backend API

Node.js (Express) + MongoDB (Mongoose) REST API for the Employee Attendance Management System. Implements the shared contract in `../docs/API_CONTRACT.md` exactly.

## Requirements

- Node.js 18+ (developed on Node 26)
- MongoDB running on `127.0.0.1:27017`

## Setup

```bash
cd backend
npm install
cp .env.example .env   # then fill in JWT_SECRET and QR_SECRET
npm run seed           # wipe-and-recreate sample data (idempotent)
npm start              # or: npm run dev (auto-restart on change)
```

The API listens on `http://localhost:5000` with base path `/api/v1`.

### Environment (`.env`)

| Variable | Description |
|---|---|
| `PORT` | HTTP port (default 5000) |
| `MONGODB_URI` | e.g. `mongodb://127.0.0.1:27017/attendance_system` |
| `JWT_SECRET` | Random string used to sign HS256 JWTs |
| `JWT_EXPIRES_IN` | Token lifetime (default `7d`) |
| `QR_SECRET` | Base64-encoded 32-byte AES-256-GCM key (`openssl rand -base64 32`) |
| `CORS_ORIGIN` | `*` or comma-separated list of allowed origins |

## Scripts

| Script | What it does |
|---|---|
| `npm start` | Run the server (`node src/server.js`) |
| `npm run dev` | Run with auto-reload (`node --watch`) |
| `npm run seed` | Wipe the database and insert seed data |

## Seeded credentials

| Role | Email | Password |
|---|---|---|
| Admin | `admin@company.com` | `Admin@123` |
| Employees | `emp1@company.com` … `emp8@company.com` | `Employee@123` |

Seed also creates the office settings singleton (lat `25.1972`, lng `55.2744`, radius `150` m, hours `09:00–18:00`, tolerances `10` min, QR refresh `30` s, timezone `Asia/Dubai`), 3 departments and 4 designations.

## Endpoint overview (base `/api/v1`)

- **Auth:** `POST /auth/login`, `GET /auth/me`, `POST /auth/change-password`
- **Employees (admin):** `GET|POST /employees`, `GET|PUT|DELETE /employees/:id` (`?hard=true` for permanent delete), `POST /employees/import` (.xlsx), `GET /employees/export` (.xlsx)
- **Departments / Designations:** `GET /departments`, `GET /designations` (any role); `POST`, `PUT /:id`, `DELETE /:id` (admin, 409 when in use)
- **Office settings:** `GET /office-settings` (any), `PUT /office-settings` (admin)
- **QR (admin):** `GET /qr/current` — rotating AES-256-GCM encrypted payload
- **Attendance (employee):** `POST /attendance/scan` (QR + geofence + state machine), `GET /attendance/today`, `GET /attendance/history`, `GET /attendance/summary?month=YYYY-MM`, `POST /attendance/requests`, `GET /attendance/requests/me`
- **Attendance (admin):** `GET /attendance/live`, `GET /attendance/logs`, `PUT /attendance/:id/correct`, `POST /attendance/manual`, `GET /attendance/requests`, `PUT /attendance/requests/:id`, `GET /attendance/missing-checkouts`, `PUT /attendance/:id/resolve-checkout`
- **Dashboard (admin):** `GET /dashboard/stats`, `GET /dashboard/trends?period=daily|weekly|monthly`
- **Reports (admin, `&format=json|xlsx`):** `GET /reports/attendance`, `GET /reports/working-hours`, `GET /reports/late-arrivals`, `GET /reports/early-checkouts`
- **Documents:** `POST /documents` (employee, multipart, max 10 MB, pdf/jpg/jpeg/png), `GET /documents/me` (employee), `GET /documents` (admin), `GET /documents/:id/download` and `DELETE /documents/:id` (owner or admin)
- **Health:** `GET /health` (public, also at the root path)

All responses use the shared envelope: `{ "success": true, "data": … }` on success and `{ "success": false, "message": …, "errors": […] }` on failure.

## Notes

- Uploaded files are stored in `backend/uploads/` and only served through the download endpoint.
- Work/break minutes, late and early-out flags are recomputed server-side on every change; all time-of-day rules honor the configured office timezone.
- The QR code payload rotates every `qrRefreshSeconds` and scans are accepted for `qrRefreshSeconds + 15s`.
