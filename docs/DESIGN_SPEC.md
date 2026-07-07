# Design System — NexCrew Attendance

Shared visual language for **both** Flutter apps (`mobile_app/` and `admin_panel/`) so they read as one product family. Material 3 (`useMaterial3: true`), built from a single seed color. Implement these tokens once in a `theme/` folder (`app_theme.dart`, `app_colors.dart`, `app_spacing.dart`) and reuse everywhere — no hard-coded colors/margins scattered in widgets.

## Brand & color

- **Seed / primary:** Indigo `#4F46E5`. Build the scheme with `ColorScheme.fromSeed(seedColor: Color(0xFF4F46E5))` for light, and a matching `brightness: Brightness.dark` scheme. **Support light AND dark mode** (`themeMode: ThemeMode.system`).
- **Semantic status colors** (use for chips, stat accents, the attendance button — identical in both apps):
  - Present / success / Check-In ready → green `#16A34A`
  - Late / warning → amber `#D97706`
  - Absent / danger / Check-Out → red `#DC2626`
  - On leave / info → blue `#2563EB`
  - Half day → teal `#0D9488`
  - Checked-out / neutral-done → slate `#64748B`
- Never put text on a colored fill without checking contrast (WCAG AA). Use `onXxx` roles or white/`#0F172A` as appropriate. Status chips: soft tinted background (`color.withOpacity(.12)`) + saturated text/icon of the same hue.

## Typography

- Use the `google_fonts` package with **Inter** (`GoogleFonts.interTextTheme(...)`). Apply once in the theme. (Note: google_fonts fetches at first run; fine for dev. If a build/test environment is offline, the app still renders with the fallback — do not let it break `flutter test`.)
- Scale: Display/headline for screen titles and the big attendance state; `titleMedium`/`titleLarge` for section headers and card titles; `bodyMedium` for content; `labelSmall`/`labelMedium` (letter-spacing ~0.3) for chips, captions, table headers. Numbers in stats: large, `FontWeight.w700`, tabular feel.

## Shape, spacing, elevation

- **Spacing scale** (constants): 4, 8, 12, 16, 20, 24, 32. Screen padding 16–20. Gaps between cards 12–16.
- **Radius:** cards 20, buttons 14, chips/pills 999 (stadium), text fields 12, bottom sheets 28 (top corners).
- **Elevation:** prefer flat surfaces with a hairline border (`outlineVariant`) or a very soft shadow (`BoxShadow` blur 20, y 6, `black.opacity .04–.06`). Avoid heavy Material 2 drop shadows. Use `surfaceContainer*` tones to separate layers.
- Every card is a rounded `Container`/`Card` with consistent padding (16) and the token radius.

## Reusable components (build these, use everywhere)

`AppCard`, `SectionHeader(title, action?)`, `StatusChip(status)`, `StatTile(icon, label, value, accentColor)`, `PrimaryButton`/`AppButton` (filled, tonal, outline, danger variants; loading state), `AppTextField`, `EmptyState(icon, title, message, action?)`, `LoadingState` (skeleton shimmer or centered spinner), `ErrorState(message, onRetry)`, `AppAvatar(name)` (initials on tinted circle). Every list/async view MUST render distinct loading, empty, and error states — never a bare spinner or blank screen.

## Motion

- Subtle only: 150–250ms ease transitions, `AnimatedSwitcher` for the attendance state change, gentle scale/opacity on button press, animated count-up on dashboard numbers is a nice touch. No gratuitous animation.

---

## Mobile app (`mobile_app/`) — screen direction

Employee-facing, phone. Bottom navigation: **Home · History · Requests · Profile** (Documents opens from Profile).

- **Splash / auth gate:** brand mark centered on primary gradient; quick token check → Login or Home.
- **Login:** clean centered card on a soft gradient/blurred background; logo, email + password fields with icons and inline validation, a full-width primary button with loading state, friendly server-error banner.
- **Home (the hero screen):** gradient app-bar area with greeting ("Good morning, Jane"), today's date, and an `AppAvatar`. Below, a large **attendance status card** showing today's state (Not checked in / Working since 09:04 / Completed — 8h 12m) with a live-ticking worked duration when active. Then the **single big context-aware action button** (full-width, ~64pt tall, rounded 14, icon + label):
  - not checked in → **"Check In"**, green.
  - checked in, not out → **"Check Out"**, red/amber.
  - checked out → a done state (button becomes a disabled "Completed for today" with a checkmark, or a summary chip). Never show two action buttons; there are NO break buttons.
  Tapping opens the scanner directly for the correct action. Below the button, a small timeline: Checked in • 09:04 / Checked out • 18:10, plus a Late/Early chip when relevant.
- **Scanner:** full-screen camera with a stylish rounded scan-window overlay, dimmed surround, a header showing which action is in progress ("Scanning to Check In"), and a hint line. On detect → stop camera, get GPS, POST scan, then a **success bottom sheet**: big circular check, action + time, status chip, worked-so-far; or an error sheet showing the server message (geofence/QR/state) with a Retry button. Guard double-submits.
- **History:** date-range filter chip row; list of day cards (date, in/out times, worked duration, status chip) with tidy empty/loading states; tap → detail sheet (times, location note, correction note if any). No break info.
- **Monthly summary:** month picker header; a grid of `StatTile`s — Present, Late, Absent, Leave, Total hours, Avg hours/day (NO break tile). Optional simple bar/donut of present-vs-absent.
- **Requests:** list of own regularization requests with status chips; FAB → form (date, type dropdown, requested time fields as the type needs, reason) → submit with success feedback.
- **Profile:** header with avatar + name + employeeId; info rows (email, department, designation, phone, address, joining date); actions: Change Password (dialog), My Documents (→ documents screen), Logout (confirm).
- **Documents:** list own docs (type icon, name, size, date); upload FAB (pick pdf/jpg/png ≤10MB + type + name); download / delete with confirm. Loading/empty states.

## Admin panel (`admin_panel/`) — screen direction

Flutter **Web**, desktop-first, responsive. Left **NavigationRail** (extended ≥1100px, icon-only below; drawer on narrow) with brand header + admin name + logout at the bottom. Top bar with page title + date. Sections:

- **Dashboard:** responsive grid of `StatTile` cards (Total employees, Present, Late, Absent, On leave, Checked out, Avg hours, Attendance rate %) each with an icon and its semantic accent (NO "on break" card). Below, a **trends card** with a daily/weekly/monthly segmented toggle rendering an `fl_chart` grouped bar chart of present/late/absent using the exact semantic colors (green/amber/red), with axis labels, gridlines, tooltips, and a legend. Optional "today at a glance" mini live list.
- **Live Attendance:** auto-refreshing (~30s) modern table — Employee (avatar+name+id), Department, Check-in, Check-out, and a `liveStatus` chip (`NOT_IN | WORKING | CHECKED_OUT | ON_LEAVE` — no ON_BREAK). Summary chips row on top; department filter; a manual refresh + "last updated" label.
- **Attendance Logs:** filter bar (employee search dropdown, date range, status); paginated table; per-row **Correct** action (dialog editing checkIn / checkOut / status + required note — NO breaks field); toolbar **Manual Entry** (employee, date, times or ON_LEAVE status, note).
- **Requests:** Pending / Approved / Rejected tabs; approve/reject with optional note.
- **Missing Check-outs:** date picker (default yesterday); list of open records; **Resolve** dialog (checkOut time + note).
- **Employees:** searchable, filterable paginated table (avatar, id, name, email, department, designation, active badge); Add/Edit dialogs (all contract fields, dropdowns for department/designation, password optional on edit); soft-delete with confirm; **Import** (.xlsx → show imported/skipped + per-row errors in a dialog); **Export** (.xlsx download via the authenticated bytes → Blob helper).
- **Departments & Designations:** two clean CRUD lists (add / rename / delete; surface the in-use 409 nicely).
- **Office Settings:** form for latitude, longitude, radiusMeters, workStartTime & workEndTime (time pickers), lateToleranceMinutes, earlyLeaveToleranceMinutes, timezone (NO qrRefreshSeconds field) → save with success toast; a small map-less "geofence preview" (radius + coords echo) is a nice touch.
- **QR Display (kiosk):** a polished centered card showing the **permanent** QR large (`qr_flutter` rendering `qrData` from `GET /qr/current`) with a "Generated <relative/absolute time>" line and a **version badge** — **NO countdown, NO auto-refresh**. A prominent **Regenerate QR** button that opens a confirm dialog warning "This invalidates the current code — anyone using the old printed QR will need the new one," then calls `POST /qr/regenerate` and swaps in the new code with a success toast. Suitable to leave full-screen on a display at the office entrance.
- **Reports:** report-type selector (Daily / Weekly / Monthly / Working Hours / Late Arrivals / Early Check-outs) with the date controls each needs; results table (durations shown as `h:mm`, NO break columns); **Export Excel** button downloading the same query with `format=xlsx` via the authenticated download helper.

Keep it consistent: same cards, chips, spacing, and status colors as the mobile app. Data-dense but clean — generous whitespace, clear hierarchy, hover/pressed states on interactive rows.
