# Fast-O-Clock — Fresh Flutter Native Plan

Simplified, ad-free, offline-first intermittent fasting tracker for personal and family use (inspired by *Fasting - Intermittent Fasting*).

---

## Scavenged Identity & Concepts

Preserved from the previous prototypes:

- **App Identity:**
  - Name: `Fast O'Clock`
  - Bundle / App ID: `com.neurral.fast_oclock`
  - Slogan: `time to fast`
  - Tagline: `a simple fasting tracker for beginners and pros alike`
  - Copyright: `pinoy.dev`
- **UX & Flow Concepts:**
  - Optional splash / first-run onboarding (`isOnboarded` flag) → main 3-tab shell (`Fasting`, `Timeline`, `You / Settings`).
  - Dark-first theme with Light/System toggle.
  - Responsive navigation (`BottomNavigationBar` on phones, `NavigationRail` on tablets/wide screens).
  - Credits / About view in Settings.

---

## Core Design Principles

- **Offline-first & private:** Zero accounts, zero cloud sync, zero ads/paywalls. All data stored locally on device.
- **Timestamp-based timer:** Store `startTime` + `targetDurationMinutes`. Elapsed/remaining time computed from `DateTime.now()` — accurate across app kills and reboots without background timer services.
- **Simple, minimal dependencies:** Stick to well-maintained Flutter packages (`shared_preferences`, `sqflite`, `flutter_local_notifications`, `timezone`, `provider` or `ChangeNotifier`).

---

## Feature Scope (MVP)

### 1. Fasting Protocols (Presets + Custom)
- Built-in presets: `14:10`, `16:8` (default), `18:6`, `20:4`, `23:1 (OMAD)`, `36h`, plus **Custom** duration.
- Quick switch before starting (or adjust goal mid-fast).

### 2. Main Timer Screen (`Fasting`)
- Circular progress ring (`CustomPainter`) showing:
  - Elapsed time (or remaining time toggle)
  - Target end time (e.g., `Ends Today 12:00 PM`)
  - Current metabolic phase badge (e.g., Fed → Blood Sugar Drop → Fat Burning → Ketosis → Autophagy)
- Single primary CTA: **Start Fast** / **End Fast**.
- Editable **Start Time** (common real-world need: "forgot to tap start 30 mins ago") and **End Time** when logging/finishing.
- Optional quick note/mood on fast completion.

### 3. History & Timeline (`Timeline`)
- Chronological list of completed fasts (date, protocol, actual duration, goal met/missed indicator).
- Edit or delete past entries; manual "Add Past Fast" option.
- Simple summary metrics: current streak, total fasts, average fast duration, weekly completion bar.

### 4. Local Notifications
- Scheduled notification when **fasting goal is reached**.
- Optional reminder when **eating window is ending** (next fast due).
- Cancelled/rescheduled automatically on fast end or goal edit.

### 5. Settings (`Settings`)
- Default fasting protocol.
- Notification toggles (goal reached, eating window reminder).
- Theme mode (System / Dark / Light).
- JSON export / import (simple manual backup/restore for family devices).

---

## Architecture & Design Specifications

Detailed architecture and specifications live in `/design`:
- [`design/ARCHITECTURE.md`](design/ARCHITECTURE.md) — System invariants, root project layout, state flow, notification lifecycle, dependency matrix.
- [`design/DATA_MODEL.md`](design/DATA_MODEL.md) — Single-table SQLite schema (`fast_records` for active + completed fasts), non-overlapping time validation, streak math, versioned JSON backup format.
- [`design/UI_SPEC.md`](design/UI_SPEC.md) — Dark-first theme tokens, adaptive 3-tab shell, screen states, and `FastEditorSheet` validation UX.

```text
/Volumes/Dev/lab/fast-o-clock/  # Root Flutter project
├── design/
│   ├── ARCHITECTURE.md
│   ├── DATA_MODEL.md
│   └── UI_SPEC.md
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── models/        (fast_record, fast_protocol, metabolic_stage, app_settings)
│   ├── services/      (database_service, preferences_service, notification_service, backup_service)
│   ├── state/         (fasting_controller)
│   ├── screens/       (onboarding_screen, fasting_screen, timeline_screen, settings_screen)
│   └── widgets/       (timer_ring, metabolic_badge, protocol_picker, fast_editor_sheet)
└── test/
```

---

## Implementation Phases

1. **Phase 0 — Bootstrap**
   - Run `flutter create` at repository root; add core dependencies; configure Android/iOS app name, bundle ID (`com.neurral.fast_oclock`), and notification permissions.
2. **Phase 1 — Data & Controller**
   - Implement `FastRecord`, `FastProtocol`, `MetabolicStage`, `AppSettings`, `DatabaseService` (single SQLite table + overlap validation), `PreferencesService`, `BackupService`, and `FastingController` with unit tests.
3. **Phase 2 — Core UI**
   - Build adaptive 3-tab shell (`Fasting`, `Timeline`, `Settings`) + `OnboardingScreen`, `TimerRing`, `MetabolicBadge`, `ProtocolPicker`, and `FastEditorSheet`.
4. **Phase 3 — Notifications**
   - Wire `NotificationService` to schedule/cancel Goal Reached (`1001`) and Eating Window (`1002`, `<24h` protocols) alerts on Android & iOS.
5. **Phase 4 — History, Stats & Backup**
   - Wire timeline list, edit/delete/manual-add with overlap checks, consecutive goal-met day streak & 7-day bar, and JSON export/import (Merge by ID + Replace All).
6. **Phase 5 — Polish & Family Distribution**
   - App icon, splash screen, physical device testing, release APK (Android) / Xcode archive or TestFlight (iOS).

---

## UI/UX Testing Feedback (To Implement)

### 1. Theming & Material You
- **Default App Palette:** Preserve current color palette as the default app palette.
- **Android Dynamic Color (Material You):** If user's Android device has a non-monochrome (non-black-and-white) Material You theme, apply it across the app; otherwise fall back to the default app palette.
- **Splash Isolation:** Splash screen and splash icon must always use the default app palette (never override with user Material You theme).

### 2. Splash Screen
- **Brand Typography:** Make `"Fast O'Clock"` splash text bold to match the Fasting screen header style.

### 3. Fasting Screen Layout (AlamUI DZ/IZ)
- **`AppBrandTitle` Component:** Combine `"Fast O'Clock"` and `"time to fast"` into a single `AppBrandTitle` component anchored at the top of the screen, with `space-between` spacing below it.
- **Timer Positioning & Bottom Action:** Center the circular timer on-screen offset ~25% above screen center, with the **Begin Fast** (formerly Start Fast) button anchored at the bottom (`space-between` before and after the circular timer).
- **Preset Dropdown Placement:** Move the Preset dropdown directly above the **Begin Fast** button.

### 4. Timer Ring — Ready / Eating Window State
- **Last Fast Notification Panel:** Move `"Last ended XX ago"` out of the timer ring into a tappable notification panel between `AppBrandTitle` and the timer ring, revised to `"Last fast ended xx ago"`. Tapping jumps to the `Timeline` screen and autofocuses that fast record (autofocus can be stubbed if complex; tab/screen jump required).
- **Eating Window Icon:** Replace the hourglass icon with a spoon-fork-plate icon at **2x** the current size.
- **Smart Eating Window Label:** For protocols `< 24h` (up to OMAD, `eatingWindow = 24h - fastingDuration`), show `"Ready to Fast?"` when elapsed time since last fast ended enters the final hour or exceeds the eating window (`elapsed >= eatingWindow - 1h`, staying `"Ready to Fast?"` even if missed); otherwise show `"Your time to eat"`. Apply last-hour detection only to `< 24h` protocols.
- **Goal Label Copy:** Change `"Target: XXh"` to `"Goal: XX hours"` (change `Target` to `Goal` and spell out the time unit).

### 5. Settings Screen
- **Fasting Patterns Header & Copy:** Retitle `"Choose Fasting Protocol"` to `"Fasting Patterns"` and add description below heading: `"Choose the most realistic and achievable option for you. Remember that the quality of food you take during your eating window is still of utmost importance."`
- **Notifications (Eating Window Ending & Permissions):**
  - Request OS notification permissions on first launch / onboarding completion (not only when toggling settings switches, since `notifyGoalReached` defaults to `true`).
  - Trigger eating-window-ending notification **15 minutes before** the end of the eating window, and schedule it if enabled while already in an eating window.
- **Data Backup Labels:** Remove `"JSON"` from option names → `"Export Backup to your Files"` and `"Import Backup from your Files"`.
- **About / Copyright:** Remove package ID from copyright line; dynamically use current year (`YEAR. neurral and pinoy.dev`).

### 6. Tumbler DateTime Picker (Replace Calendar & Clock Pickers)
- **Remove Native Pickers:** Replace Material Calendar and Clock pickers across fast editing flows with a custom `TumblerDateTimePicker` widget.
- **Date Tumbler (`YYYY | MM | DD [DAY]`):** Wheel/tumbler numeric pickers for `YYYY`, `MM`, `DD` (clamping valid days per month/leap year) + read-only `[DAY]` label in dimmer color auto-showing weekday (`MON`, `TUE`, etc.).
- **Time Tumbler (`AM/PM | HH | MM`):** 12-hour format (`1–12` hours, `00–59` minutes) with `AM/PM` wheel that automatically flips whenever `HH` cycles across `11 ↔ 12`.

### 7. Fasting Active State, Editor Sheet & CTAs
- **Start / Target End Panels:** Make the entire panel/label tappable; remove `"Edit"` text label, retain pencil icon.
- **Panel DateTime Format:** Display `HH:MM PM` on the left and `DATE` floated right (gap between time and date). Format `DATE` as `MMM DD • WKDAY` in smaller font size, all-caps.
- **Target End Flag Icon:** Switch to green check-flag Material icon once the fast passes its goal duration.
- **Edit Ongoing Fast Sheet:**
  - Rename `"Edit Active Fast"` → `"Edit Ongoing Fast"`.
  - Remove Protocol selector from this sheet (use Preset dropdown on Fasting screen instead).
  - Immediately display `TumblerDateTimePicker` inline (defaulting to current fast timestamp / today).
  - Bottom action row: red trash icon + `"Delete"` label on the left (sized to text/content width), paired inline with **Save** button (`Expanded` to fill remaining width).
- **Primary Fasting CTAs:**
  - Rename `"Start Fast"` → `"Begin Fast"`.
  - Rename `"Complete Fast"` → `"Fast Complete?"`, remove checkbox icon, retain green coloring.

### Deferred (Future)
- **Day-Based / Recurring Fasting Patterns** (ADF, 1 day/week, 5-day) — deferred pending streak calculation analysis.
- **Google Drive Backup** — deferred; focus on local file backup improvements first.
