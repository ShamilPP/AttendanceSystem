# API Contract — Employee Attendance Management System

This document is the single source of truth for the REST API shared by:

- `backend/` — Node.js (Express) + MongoDB (Mongoose)
- `mobile_app/` — Flutter employee app
- `admin_panel/` — Flutter Web admin panel

All three implementations MUST follow this contract exactly.

---

## Conventions

- **Base URL:** `http://localhost:5000/api/v1`
- **Auth:** `Authorization: Bearer <JWT>` header on every endpoint except `POST /auth/login`.
- **Roles:** `admin`, `employee`. Endpoints marked **[admin]** require role `admin`; **[employee]** require `employee`; **[any]** allow both.
- **Content type:** JSON unless marked `multipart/form-data`.
- **Dates:** calendar days are strings `YYYY-MM-DD`; timestamps are ISO-8601 UTC strings (e.g. `2026-07-07T04:05:00.000Z`). Times of day (office hours) are `HH:mm` 24h strings.
- **IDs:** MongoDB ObjectId hex strings, field name `_id` in responses.
- **Pagination:** query `?page=1&limit=20`; paginated responses include `pagination: { page, limit, total, totalPages }`.

### Response envelope

Success:
```json
{ "success": true, "data": <payload>, "pagination": { ... } }
```

Error (4xx/5xx):
```json
{ "success": false, "message": "Human readable reason", "errors": [ { "field": "email", "message": "..." } ] }
```

`errors` is optional (validation only). HTTP codes: 400 validation, 401 bad/missing token, 403 wrong role or geofence/QR rejection, 404 not found, 409 conflict (duplicate email/employeeId, duplicate check-in), 500 server.

---

## Core objects

### User (employee or admin)

```json
{
  "_id": "...",
  "employeeId": "EMP-0001",
  "name": "Jane Doe",
  "email": "jane@company.com",
  "role": "employee",
  "department": { "_id": "...", "name": "Engineering" },
  "designation": { "_id": "...", "name": "Software Engineer" },
  "phone": "+971500000000",
  "address": "…",
  "joiningDate": "2025-01-15",
  "isActive": true,
  "createdAt": "...", "updatedAt": "..."
}
```

`department`/`designation` are populated objects in responses; requests send them as id strings `departmentId`, `designationId`. Password is write-only (`password` field on create/update), stored bcrypt-hashed, never returned.

### Attendance record (one per employee per day)

```json
{
  "_id": "...",
  "employee": { "_id": "...", "employeeId": "EMP-0001", "name": "Jane Doe", "department": { "_id": "...", "name": "Engineering" } },
  "date": "2026-07-07",
  "checkIn": "2026-07-07T04:05:00.000Z",
  "checkOut": "2026-07-07T13:02:00.000Z",
  "breaks": [ { "start": "2026-07-07T08:00:00.000Z", "end": "2026-07-07T08:30:00.000Z" } ],
  "workMinutes": 508,
  "breakMinutes": 30,
  "status": "PRESENT",
  "isLate": false,
  "isEarlyOut": false,
  "checkInLocation": { "latitude": 25.1972, "longitude": 55.2744 },
  "checkOutLocation": { "latitude": 25.1972, "longitude": 55.2744 },
  "correction": { "correctedBy": "<userId>", "note": "…", "correctedAt": "..." }
}
```

- `status`: `PRESENT | LATE | ABSENT | ON_LEAVE | HALF_DAY`. A late check-in stores `status: "LATE"` and `isLate: true` (LATE counts as present for headcounts).
- `checkOut`, `breaks[i].end` may be `null` while open. `workMinutes`/`breakMinutes` are recomputed by the server on every change; `workMinutes` excludes break time.
- `correction` present only if an admin edited the record.

### Office settings (singleton)

```json
{
  "latitude": 25.1972,
  "longitude": 55.2744,
  "radiusMeters": 150,
  "workStartTime": "09:00",
  "workEndTime": "18:00",
  "lateToleranceMinutes": 10,
  "earlyLeaveToleranceMinutes": 10,
  "qrRefreshSeconds": 30,
  "timezone": "Asia/Dubai"
}
```

Late = check-in after `workStartTime + lateToleranceMinutes` (in `timezone`). Early-out = check-out before `workEndTime - earlyLeaveToleranceMinutes`.

### Attendance request (regularization, employee-submitted)

```json
{
  "_id": "...",
  "employee": { "_id": "...", "employeeId": "...", "name": "..." },
  "date": "2026-07-05",
  "type": "MISSED_CHECK_IN",
  "requestedCheckIn": "2026-07-05T04:00:00.000Z",
  "requestedCheckOut": null,
  "reason": "Forgot to scan",
  "status": "PENDING",
  "reviewedBy": null, "reviewNote": null,
  "createdAt": "..."
}
```

`type`: `MISSED_CHECK_IN | MISSED_CHECK_OUT | FULL_DAY | LEAVE`. `status`: `PENDING | APPROVED | REJECTED`. Approval applies the requested values to the attendance record (creating it if absent; `LEAVE` sets `status: "ON_LEAVE"`).

### Document

```json
{
  "_id": "...",
  "employee": "<userId>",
  "type": "ID_PROOF",
  "name": "Passport",
  "fileName": "passport.pdf",
  "mimeType": "application/pdf",
  "size": 123456,
  "uploadedAt": "..."
}
```

`type`: `ID_PROOF | COMPANY_ID | OTHER`. Files stored on disk under `backend/uploads/`; served only through the download endpoint.

---

## Endpoints

### Auth

| Method | Path | Role | Body → Response |
|---|---|---|---|
| POST | `/auth/login` | public | `{ email, password }` → `data: { token, user: User }` |
| GET | `/auth/me` | any | → `data: User` |
| POST | `/auth/change-password` | any | `{ currentPassword, newPassword }` → `data: { message }` |

JWT payload: `{ sub: <userId>, role, employeeId }`, HS256, expiry from env `JWT_EXPIRES_IN` (default `7d`).

### Employees **[admin]**

| Method | Path | Notes |
|---|---|---|
| GET | `/employees` | `?search=&departmentId=&designationId=&isActive=&page=&limit=`. `search` matches name/email/employeeId (case-insensitive). |
| POST | `/employees` | `{ employeeId?, name, email, password, departmentId, designationId, phone?, address?, joiningDate?, role? }`. Omitted `employeeId` is auto-generated (`EMP-0001`, …). Returns created User. |
| GET | `/employees/:id` | |
| PUT | `/employees/:id` | Any subset of create fields (password optional). |
| DELETE | `/employees/:id` | Soft delete: sets `isActive: false`. `?hard=true` removes permanently. |
| POST | `/employees/import` | multipart field `file` (.xlsx). Columns (header row, exact): `Employee ID, Name, Email, Password, Department, Designation, Phone, Address, Joining Date`. Department/Designation matched by name, created if missing. → `data: { imported, skipped, errors: [{ row, message }] }` |
| GET | `/employees/export` | Returns `.xlsx` file (same columns, no Password) with `Content-Disposition: attachment`. |

### Departments & Designations **[admin]** (GET list is **[any]**)

`/departments` and `/designations`, identical shape `{ _id, name, description? }`:
GET `/` (list, any role) · POST `/` `{ name, description? }` · PUT `/:id` · DELETE `/:id` (409 if in use by an employee).

### Office settings

| Method | Path | Role |
|---|---|---|
| GET | `/office-settings` | any |
| PUT | `/office-settings` | admin — full or partial object from “Office settings” above |

### QR **[admin]**

| Method | Path | Response |
|---|---|---|
| GET | `/qr/current` | `data: { qrData: "<opaque base64 string>", expiresAt: "<ISO>", refreshSeconds: 30 }` |

`qrData` is AES-256-GCM–encrypted JSON `{ t: <issuedAt ms>, n: <nonce> }`, key from env `QR_SECRET` (encoded `base64(iv):base64(ciphertext):base64(authTag)`). The admin panel renders it as a QR image and re-fetches every `refreshSeconds`. A scanned code is valid for `qrRefreshSeconds + 15s` grace.

### Attendance — employee

| Method | Path | Body / Query |
|---|---|---|
| POST | `/attendance/scan` | `{ qrData, action, latitude, longitude }`, `action ∈ CHECK_IN | CHECK_OUT | BREAK_START | BREAK_END` → `data: { attendance: Attendance, message }` |
| GET | `/attendance/today` | → `data: Attendance \| null` |
| GET | `/attendance/history` | `?from=&to=&page=&limit=` → paginated `data: [Attendance]`, newest first |
| GET | `/attendance/summary` | `?month=YYYY-MM` → see below |
| POST | `/attendance/requests` | `{ date, type, requestedCheckIn?, requestedCheckOut?, reason }` |
| GET | `/attendance/requests/me` | `?status=&page=` |

**Scan validation order (server-side):** ① QR decrypts and is fresh → else 403 `"Invalid or expired QR code"`; ② geofence: haversine(location, office) ≤ `radiusMeters` → else 403 `"You are outside the allowed office area (Xm away, limit Ym)"`; ③ state machine: CHECK_IN once per day (409 if repeated); CHECK_OUT/BREAK_* require prior check-in; BREAK_START requires no open break; BREAK_END requires an open break; CHECK_OUT auto-closes an open break and rejects a second check-out (409). Late/early flags & minutes computed on the spot.

**Monthly summary response:**
```json
{ "month": "2026-07", "workingDays": 23, "presentDays": 20, "lateDays": 3, "absentDays": 2, "leaveDays": 1, "halfDays": 0, "totalWorkMinutes": 9700, "totalBreakMinutes": 610, "averageWorkMinutes": 485, "earlyOutDays": 1, "records": [Attendance] }
```
`workingDays` = Mon–Fri in month up to today (future days excluded). `absentDays` = workingDays − days with any attendance/leave.

### Attendance — admin

| Method | Path | Notes |
|---|---|---|
| GET | `/attendance/live` | `?departmentId=` → `data: { date, summary: { total, present, late, absent, onLeave, checkedOut, onBreak }, records: [ { employee, attendance: Attendance \| null, liveStatus } ] }` — one row per active employee; `liveStatus ∈ NOT_IN | WORKING | ON_BREAK | CHECKED_OUT | ON_LEAVE` |
| GET | `/attendance/logs` | `?employeeId=&from=&to=&status=&page=&limit=` → paginated `[Attendance]` |
| PUT | `/attendance/:id/correct` | `{ checkIn?, checkOut?, breaks?, status?, note }` (note required) — recomputes minutes/flags, stores `correction` |
| POST | `/attendance/manual` | `{ employeeId, date, checkIn?, checkOut?, status?, note }` — create a record that doesn't exist (e.g. mark ON_LEAVE) |
| GET | `/attendance/requests` | `?status=&page=` — all employees' requests |
| PUT | `/attendance/requests/:id` | `{ status: "APPROVED" \| "REJECTED", reviewNote? }` |
| GET | `/attendance/missing-checkouts` | `?date=` (default: yesterday) → records with `checkIn` set, `checkOut` null |
| PUT | `/attendance/:id/resolve-checkout` | `{ checkOut, note }` |

### Dashboard **[admin]**

| Method | Path | Response `data` |
|---|---|---|
| GET | `/dashboard/stats` | `?date=` (default today) → `{ totalEmployees, present, absent, late, onLeave, onBreak, checkedOut, averageWorkMinutes, attendanceRate }` (`attendanceRate` = present incl. late ÷ totalEmployees, 0–100) |
| GET | `/dashboard/trends` | `?period=daily\|weekly\|monthly` → `{ period, points: [ { label, present, late, absent } ] }` — daily: last 14 days (`label` = `YYYY-MM-DD`); weekly: last 8 ISO weeks (`2026-W27`); monthly: last 6 months (`2026-07`) |

### Reports **[admin]**

All accept `&format=json` (default) or `&format=xlsx` (file download, `Content-Disposition: attachment`).

| Method | Path | Query |
|---|---|---|
| GET | `/reports/attendance` | `type=daily&date=` or `type=weekly&from=&to=` or `type=monthly&month=YYYY-MM`, optional `departmentId` → per-employee rows: `{ employeeId, name, department, presentDays, lateDays, absentDays, leaveDays, totalWorkMinutes, totalBreakMinutes }` (daily returns the day's Attendance-like rows with times) |
| GET | `/reports/working-hours` | `month=YYYY-MM` → `{ employeeId, name, department, totalWorkMinutes, totalBreakMinutes, averageWorkMinutes, daysWorked }` |
| GET | `/reports/late-arrivals` | `from=&to=` → `{ employeeId, name, department, date, checkIn, minutesLate }` |
| GET | `/reports/early-checkouts` | `from=&to=` → `{ employeeId, name, department, date, checkOut, minutesEarly }` |

### Documents

| Method | Path | Role | Notes |
|---|---|---|---|
| POST | `/documents` | employee | multipart: `file`, `type`, `name`. Max 10 MB; pdf/jpg/jpeg/png only. |
| GET | `/documents/me` | employee | list own |
| GET | `/documents` | admin | `?employeeId=` |
| GET | `/documents/:id/download` | any | owner or admin; streams the file |
| DELETE | `/documents/:id` | any | owner or admin |

### Health

`GET /health` (public) → `{ success: true, data: { status: "ok" } }`

---

## Backend environment (`backend/.env`, with `.env.example` committed)

```
PORT=5000
MONGODB_URI=mongodb://127.0.0.1:27017/attendance_system
JWT_SECRET=<random>
JWT_EXPIRES_IN=7d
QR_SECRET=<32-byte base64>
CORS_ORIGIN=*
```

`npm run seed` creates: admin `admin@company.com` / `Admin@123`, office settings (defaults above), 3 departments, 4 designations, and 8 sample employees `emp1@company.com` … / `Employee@123`.
