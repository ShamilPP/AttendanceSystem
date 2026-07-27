# Design System — NexCrew Attendance

Shared visual language for **both** Flutter apps (`mobile_app/` and `admin_panel/`) so they read as one product family. Material 3 (`useMaterial3: true`), built from a single seed color. Implement these tokens once in a `theme/` folder (`app_theme.dart`, `app_colors.dart`, `app_spacing.dart`) and reuse everywhere — no hard-coded colors/margins scattered in widgets.

## Product names & app icons

| | Employee app | Admin panel |
|---|---|---|
| Name | **NexCrew Attendance** | **NexCrew Admin** |
| PWA short name | NexCrew | NexCrew Admin |
| `theme_color` / `background_color` | `#4F46E5` / `#4F46E5` | `#312E81` / `#0F172A` |
| Icon gradient | `#6366F1 → #4338CA` | `#0F172A → #3730A3` |

The icon mark is a **fingerprint**, the same glyph already used as the in-app brand mark (admin rail, login, QR kiosk). Both apps share one shape and differ only by gradient, so they read as a family while staying tellable apart in a browser tab strip or app drawer.

Icons are **generated from code** by `tools/generate_icons.py` — never hand-edit the PNGs; change the palette or glyph there and re-run. Two craft rules baked in:

- **Small sizes get a simplified glyph.** Five fingerprint ridges turn to mush below ~48px, so favicons and tiny iOS slots use a three-ridge, thicker-stroke variant with the same silhouette.
- **Maskable ≠ standard.** Android/PWA maskable icons are cropped to a circle by the OS, so they are full-bleed with the glyph inside the 80% safe zone; standard icons carry the rounded-square tile (22% radius); iOS is square because the system applies its own squircle.

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

`AppCard`, `SectionHeader(title, action?)`, `StatusChip(status)`, `StatTile(icon, label, value, accentColor, onTap?, hint?)`, `PrimaryButton`/`AppButton` (filled, tonal, outline, danger variants; loading state), `AppTextField`, `EmptyState(icon, title, message, action?)`, `LoadingState`, `ErrorState(message, onRetry)`, `AppAvatar(name)` (initials on tinted circle). Every list/async view MUST render distinct loading, empty, and error states — never a bare spinner or blank screen.

Admin panel adds: `PageScaffold(title, description?, actions?, tabs?)` — the standard page header + URL-driven sub-tab strip used by every section; `Skeleton` / `StatGridSkeleton` / `TableSkeleton` — shape-matched placeholders.

**Loading rule:** anything with a known shape (a table, a stat grid) loads as a **skeleton**, not a centered spinner, so the layout does not jump when data lands. Reserve `LoadingState` for genuinely unknown-shape content.

## Forms & layout rules

Learned from a settings screen that shipped looking broken. These are not style preferences — each one fixes a specific way the UI read as buggy.

1. **Never wrap an input in `Expanded` just because it is in a `Row`.** Size controls to their content: a two-digit minutes field is ~120px, a time is ~150px, not half the card. Use `SettingRow` (explanatory label left, control right) for settings, and `FormRow` for genuinely paired fields in dialogs.
2. **Rows of fields must top-align.** A plain `Row` centres its children, so pairing a field that has `helperText` with one that does not shoves the taller one's label visibly out of line. `SettingRow`/`FormRow` do this for you; if you hand-roll a row, set `crossAxisAlignment: CrossAxisAlignment.start`.
3. **Scrollable content needs soft edges.** `PageScaffold` wraps its child in `FadingScrollView`, so a heading scrolled under the fixed header dissolves instead of being sliced through the middle of its glyphs. The fade only appears on an edge that actually has content beyond it.
4. **A preview must reflect what is being edited, not what was saved.** The geofence preview originally read the saved settings, so changing the radius never moved it — a control that silently lies.
5. **Destructive-free saving.** Long forms get a pinned save bar that appears only when something changed, with Discard beside it — never a lone button buried at the bottom of a tall card.
6. **Units belong in a suffix**, not the label: `Radius [150] m`, not `Radius (meters) [150]`.
7. **Check dark mode explicitly.** M3's `outlineVariant` is too dim on a dark surface for input borders (fields dissolve into the background), and `SegmentedButton`'s default unselected segment renders as a glaring white block. Both are themed centrally in `app_theme.dart`.

### Reviewing screens without a backend

`admin_panel/test/screenshots_test.dart` renders screens to `test/goldens/*.png` with stubbed providers, so layout can be looked at rather than guessed at:

```bash
flutter test --tags screenshots --update-goldens
```

It is skipped in normal runs (see `dart_test.yaml`). Text is rendered in a substituted system font because google_fonts cannot fetch Inter offline; sizes, weights and every other token are the real theme.

## Navigation & information architecture

Two rules earned the hard way; both apps follow them.

**1. Every count is a link.** A number that names a set of people (Absent: 5, 3 pending requests) must be tappable and land on that filtered set. A read-only count forces the user to re-find the same information by hand. Aggregates with no set behind them (averages, percentages) stay non-interactive and must not render a tap affordance.

**2. One question, one door.** If two screens answer the same question at different zoom levels, group them as tabs rather than scattering them across the navigation. Duplicate entry points to the same destination are worse than one.

### Admin panel (Flutter Web)

The panel is a **web app**: every section owns a real URL via `go_router`, so browser back, bookmarks, deep links and reload-in-place all work. The shell is built once by a `ShellRoute` — switching sections must never rebuild (and reset the filters/scroll of) the screen being left. Unauthenticated deep links round-trip through `/login?from=…`.

Navigation is two groups — the daily loop, then setup:

| Group | Item | Route | Notes |
|---|---|---|---|
| Daily | Overview | `/` | |
| | Attendance | `/attendance/{live,logs,missing}` | tabs; badge = missing check-outs |
| | Requests | `/requests` | badge = pending count |
| | People | `/people/{employees,catalog}` | tabs |
| | Reports | `/reports` | |
| Setup | QR code | `/qr` | |
| | Settings | `/settings` | |
| — | Kiosk | `/kiosk` | **outside** the shell: no chrome, no destructive actions |

Nav badges come from `AttentionProvider`, which polls the two queues an admin must *act* on. A failed poll keeps the last known value rather than flashing a misleading zero.

### Mobile app

Bottom nav: **Home · Activity · Requests · Profile**, with a context-aware scan FAB (Check In → Check Out → hidden when the day is done). The FAB is suppressed on Home, which already carries the full-width hero button — the same action must not appear twice on one screen.

Activity holds History and Summary as tabs: the same records, itemised and aggregated.

## Motion

- Subtle only: 150–250ms ease transitions, `AnimatedSwitcher` for the attendance state change, gentle scale/opacity on button press, animated count-up on dashboard numbers is a nice touch. No gratuitous animation.

---

## Mobile app (`mobile_app/`) — screen direction

Employee-facing, phone. Bottom navigation: **Home · Activity · Requests · Profile** (Documents opens from Profile).

- **Splash / auth gate:** brand mark centered on primary gradient; quick token check → Login or Home.
- **Login:** clean centered card on a soft gradient/blurred background; logo, email + password fields with icons and inline validation, a full-width primary button with loading state, friendly server-error banner.
- **Home — geofence pre-flight strip (above the status card):** resolves the office geofence (`GET /office-settings`, readable by any authenticated user) against the device fix and states plainly whether a scan can succeed: "You're at the office" (green) / "You're 240 m away" with the allowed radius (amber) / a one-tap prompt to grant location. Use the **same haversine and Earth radius as `backend/src/utils/geo.js`** so the hint and the server's verdict never disagree.
  - It is a **hint, never a gate** — the action button stays enabled regardless. GPS drift must not lock someone out of their own attendance; the server is the only authority on the fence.
  - The first load checks **silently** (`askPermission: false`): it reads an already-granted permission but never raises the OS dialog on first paint. Permission is requested only from a deliberate tap. A prompt that arrives unprovoked gets denied, and a denial mid-scan strands the employee with no way forward.
- **Home — unsent-scan card:** if a scan failed because the network was unreachable (HTTP status 0 only — *not* a server rejection), offer to file a regularization request pre-filled with the original scan time. Do **not** build a silent replay queue: `POST /attendance/scan` timestamps on receipt, so retrying later records the wrong time — which is worse than losing it, because it looks correct.
- **Home (the hero screen):** gradient app-bar area with greeting ("Good morning, Jane"), today's date, and an `AppAvatar`. Below, a large **attendance status card** showing today's state (Not checked in / Working since 09:04 / Completed — 8h 12m) with a live-ticking worked duration when active. Then the **single big context-aware action button** (full-width, ~64pt tall, rounded 14, icon + label):
  - not checked in → **"Check In"**, green.
  - checked in, not out → **"Check Out"**, red/amber.
  - checked out → a done state (button becomes a disabled "Completed for today" with a checkmark, or a summary chip). Never show two action buttons; there are NO break buttons.
  Tapping opens the scanner directly for the correct action. Below the button, a small timeline: Checked in • 09:04 / Checked out • 18:10, plus a Late/Early chip when relevant.
- **Scanner:** full-screen camera with a stylish rounded scan-window overlay, dimmed surround, a header showing which action is in progress ("Scanning to Check In"), and a hint line. On detect → stop camera, get GPS, POST scan, then a **success bottom sheet**: big circular check, action + time, status chip, worked-so-far; or an error sheet showing the server message (geofence/QR/state) with a Retry button. Guard double-submits.
- **Activity (one tab, two views):**
  - *History:* date-range filter chip row; list of day cards (date, in/out times, worked duration, status chip) with tidy empty/loading states; tap → detail sheet (times, location note, correction note if any). No break info. The sheet ends with **"Request a correction"**, which opens the request form with that date pre-filled — the fix belongs where the problem is noticed, not behind a separate tab the employee has to work out on their own.
  - *Summary:* month picker header; a grid of `StatTile`s — Present, Late, Absent, Leave, Total hours, Avg hours/day (NO break tile). Optional simple bar/donut of present-vs-absent.
- **Requests:** list of own regularization requests with status chips; FAB → form (date, type dropdown, requested time fields as the type needs, reason) → submit with success feedback. The form accepts pre-filled date/type/times so other screens can hand it a case.
- **Profile:** header with avatar + name + employeeId; info rows (email, department, designation, phone, address, joining date); a **Daily reminders** toggle; actions: Change Password (dialog), My Documents (→ documents screen), Logout (confirm).
- **Daily reminders (local notifications):** a nudge shortly before the working day starts and ~15 min after it ends, scheduled from office settings so they track the configured day rather than a hard-coded hour. This exists to drain the admin's "Missing check-outs" queue **at source** — that queue is a symptom of nobody ever being reminded.
  - Notification permission is requested **only** when the employee flips the toggle on, never at launch.
  - Everything degrades quietly: denied permission, OEM battery savers and exact-alarm restrictions must leave attendance itself completely unaffected. The plugin has no web implementation, so on the Flutter-web build the service initialises to unavailable and the toggle simply reports that reminders are blocked.
  - Reminders are cleared on logout — they belong to the person who signed in, not to the device.
- **Documents:** list own docs (type icon, name, size, date); upload FAB (pick pdf/jpg/png ≤10MB + type + name); download / delete with confirm. Loading/empty states.

## Admin panel (`admin_panel/`) — screen direction

Flutter **Web**, desktop-first, responsive. Left rail (extended ≥1100px, icon-only below; drawer on narrow) with brand header + admin name + logout at the bottom, grouped per the IA table above. Each page renders its own title via `PageScaffold`; the top app bar exists only on narrow layouts (menu + account). Sections:

- **Overview:** ordered by urgency, because only the first block goes stale if ignored.
  1. **"Needs your attention"** — pending requests and unresolved check-outs, each with a direct action button. These are the only two things on the screen that require a *decision*; they must never be buried behind a nav item. When both queues are empty this collapses to a quiet one-line all-clear so it does not become noise the admin learns to skip.
  2. Responsive grid of `StatTile` cards (Total employees, Present, Late, Absent, On leave, Checked out, Avg hours, Attendance rate %) with semantic accents (NO "on break" card). **Every headcount tile drills into the live board filtered to that status**; Avg hours and Attendance rate are aggregates with no set behind them, so they stay non-interactive.
  3. **Trends card** with a daily/weekly/monthly segmented toggle rendering an `fl_chart` grouped bar chart of present/late/absent in the exact semantic colors, with axis labels, gridlines, tooltips, and a legend.
  - Auto-refreshes on a 60s timer, **silently** — the poll must not blank the numbers the admin is reading. A "Updated HH:mm" line carries the freshness.
- **Attendance** (tabs: Live board · Logs · Missing check-outs — one section, three time horizons):
  - *Live board:* auto-refreshing (~30s) table — Employee (avatar+name+id), Department, Check-in, Check-out, `liveStatus` chip (`NOT_IN | WORKING | CHECKED_OUT | ON_LEAVE`). Summary `CountChip`s on top **double as filters** (click "Not in 4" to see those four); department filter; manual refresh + "last updated". Status filtering is client-side — the endpoint has no status param.
  - *Logs:* filter bar (employee search dropdown, date range, status); paginated table; per-row **Correct** action (dialog editing checkIn / checkOut / status + required note — NO breaks field); toolbar **Manual Entry**.
  - *Missing check-outs:* date picker (default yesterday); list of open records; **Resolve** dialog (checkOut time + note). Tab badge shows the outstanding count.
- **Requests:** Pending / Approved / Rejected tabs; approve/reject with optional note. Nav badge shows the pending count.
- **People** (tabs: Employees · Departments & roles — the catalogs exist only to classify employees, so they live beside them):
  - *Employees:* searchable, filterable paginated table; Add/Edit dialogs (all contract fields, password optional on edit); soft-delete with confirm; **Import** (.xlsx → imported/skipped + per-row errors) and **Export** (.xlsx via the authenticated bytes → Blob helper).
  - *Departments & roles:* two CRUD lists side by side (add / rename / delete; surface the in-use 409 nicely).
- **Office Settings:** form for latitude, longitude, radiusMeters, workStartTime & workEndTime (time pickers), lateToleranceMinutes, earlyLeaveToleranceMinutes, timezone (NO qrRefreshSeconds field) → save with success toast. Note the mobile app reads this same endpoint for its geofence pre-flight and reminder times.
- **QR code (`/qr`):** centered card showing the **permanent** QR (`qr_flutter` rendering `qrData` from `GET /qr/current`) with a "Generated …" line and a **version badge** — **NO countdown, NO auto-refresh**. Two actions: **Open kiosk view** and **Regenerate QR** (confirm dialog warning "This invalidates the current code — anyone using the old printed QR will need the new one," then `POST /qr/regenerate`).
- **Kiosk (`/kiosk`):** the same QR rendered as large as the display allows, **outside the shell** — no rail, no top bar, and the destructive Regenerate action is deliberately **hidden**. This is what gets left running on a screen at the entrance, where a stray click must never invalidate everyone's code. Its own URL, so it can be bookmarked or opened straight into browser fullscreen.
- **Reports:** report-type selector (Daily / Weekly / Monthly / Working Hours / Late Arrivals / Early Check-outs) with the date controls each needs; results table (durations shown as `h:mm`, NO break columns); **Export Excel** button downloading the same query with `format=xlsx` via the authenticated download helper.

Keep it consistent: same cards, chips, spacing, and status colors as the mobile app. Data-dense but clean — generous whitespace, clear hierarchy, hover/pressed states on interactive rows.
