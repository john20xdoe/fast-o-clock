# Fast O'Clock — System Architecture

Offline-first, local-only intermittent fasting tracker built with Flutter.

---

## 1. Architectural Invariants

1. **Zero-Network / Local-Only**: No remote APIs, accounts, telemetry, or ads. All state lives on-device in SQLite (`sqflite`) and `SharedPreferences`.
2. **Timestamp-Driven Timer**: No background isolates or foreground services for timekeeping. Elapsed and remaining durations are pure functions of `nowUtc - startTimeUtc` evaluated on UI frame ticks (`Timer.periodic(1s)` while foregrounded) and lifecycle resume (`AppLifecycleState.resumed`).
3. **UTC Storage, Local Presentation**: Every persisted timestamp is stored in UTC epoch milliseconds (`INTEGER`). Conversion to local time occurs strictly at UI formatting, calendar-day streak grouping, and local notification scheduling boundaries.
4. **Single Source of Truth for Fasts**: Active and completed fasts reside in the same SQLite `fast_records` table. At most one row may have `end_time_ms IS NULL` at any point in time.

---

## 2. Workspace & Directory Structure

The Flutter project lives at the repository root (`/Volumes/Dev/lab/fast-o-clock/`).

```text
/Volumes/Dev/lab/fast-o-clock/
├── design/                           # Architecture & design specifications
│   ├── ARCHITECTURE.md
│   ├── DATA_MODEL.md
│   └── UI_SPEC.md
├── PLAN.md
├── pubspec.yaml
├── lib/
│   ├── main.dart                     # App bootstrap, DB/Prefs/Notification init
│   ├── app.dart                      # MaterialApp, theme binding, adaptive shell
│   ├── models/
│   │   ├── fast_record.dart          # FastRecord entity + computed duration/goal helpers
│   │   ├── fast_protocol.dart        # Presets (14:10..36h) + Custom protocol definition
│   │   ├── metabolic_stage.dart      # Elapsed-hour thresholds & copy
│   │   └── app_settings.dart         # Typed settings model
│   ├── services/
│   │   ├── database_service.dart     # sqflite setup, migrations, CRUD, overlap validation
│   │   ├── preferences_service.dart  # shared_preferences wrapper for AppSettings
│   │   ├── notification_service.dart # flutter_local_notifications + timezone scheduling
│   │   └── backup_service.dart       # Versioned JSON export & import (Merge / Replace)
│   ├── state/
│   │   └── fasting_controller.dart   # Single ChangeNotifier coordinating services & UI tick
│   ├── screens/
│   │   ├── onboarding_screen.dart    # Optional first-run intro (gated by isOnboarded)
│   │   ├── fasting_screen.dart       # Tab 1: Timer ring, protocol badge, start/end CTA
│   │   ├── timeline_screen.dart      # Tab 2: Stats summary, streak, history list & CRUD
│   │   └── settings_screen.dart      # Tab 3: Defaults, notifications, theme, backup, about
│   └── widgets/
│       ├── timer_ring.dart           # CustomPainter circular progress gauge
│       ├── metabolic_badge.dart      # Current stage pill + detail bottom sheet
│       ├── protocol_picker.dart      # Preset & custom duration selector sheet
│       └── fast_editor_sheet.dart    # Start/End/Note editor with overlap validation
└── test/
    ├── models/
    │   └── metabolic_stage_test.dart
    ├── services/
    │   ├── database_service_test.dart
    │   └── backup_service_test.dart
    └── state/
        └── fasting_controller_test.dart
```

---

## 3. Component & State Flow

```mermaid
flowchart TD
    UI["Screens & Widgets\n(Fasting / Timeline / Settings)"]
    CTRL["FastingController\n(ChangeNotifier)"]
    DB["DatabaseService\n(sqflite: fast_records)"]
    PREF["PreferencesService\n(shared_preferences)"]
    NOTIF["NotificationService\n(flutter_local_notifications)"]
    BKUP["BackupService\n(JSON Export / Import)"]

    UI -->|"User Actions"| CTRL
    CTRL -->|"notifyListeners()"| UI
    CTRL --> DB
    CTRL --> PREF
    CTRL --> NOTIF
    CTRL --> BKUP
    BKUP --> DB
    BKUP --> PREF
```

### `FastingController` Responsibilities
- Holds in-memory cache of:
  - `FastRecord? activeFast`
  - `List<FastRecord> history` (completed fasts ordered by `start_time_ms DESC`)
  - `AppSettings settings`
- Runs a `1s` periodic ticker **only** while `activeFast != null` and app is in foreground, calling `notifyListeners()` so the timer ring and elapsed text update smoothly.
- Listens to `WidgetsBindingObserver.didChangeAppLifecycleState`: pauses UI ticker when backgrounded, immediately recomputes from `DateTime.now().toUtc()` on resume.

---

## 4. Notification Lifecycle

Notification IDs are deterministic constants:
- `1001`: **Goal Reached** (`"Fasting Goal Reached!"`)
- `1002`: **Eating Window Ending** (`"Time to Start Your Next Fast"`)

| User / System Event | Notification ID `1001` (Goal Reached) | Notification ID `1002` (Eating Window Ending) |
|---|---|---|
| **Start Fast** (`start + target > now`) | Cancel `1001`; schedule at `start + target` (if `notifyGoalReached` enabled). | Cancel `1002`. |
| **Edit Active Fast** (`start` or `target` changed) | Cancel `1001`; reschedule at new `start + target` if still in the future. | Unchanged (cancelled). |
| **End Fast** (completed at `endTime`) | Cancel `1001`. | If `notifyEatingWindow` enabled **AND** protocol target `< 24h` (1440m), schedule at `endTime + (1440m - targetMinutes)` if in the future; otherwise cancel `1002`. |
| **Delete / Cancel Active Fast** | Cancel `1001`. | Cancel `1002`. |
| **Toggle Notification Setting Off** | Cancel `1001` immediately if Goal toggle disabled. | Cancel `1002` immediately if Eating Window toggle disabled. |

---

## 5. Dependency Matrix

| Package | Purpose | Notes |
|---|---|---|
| `sqflite` | Local SQLite database for `fast_records` | Core history & active fast persistence |
| `path` | Joining database file path | Standard companion to `sqflite` |
| `shared_preferences` | Lightweight key-value settings | Theme, default protocol, onboarding, notification toggles |
| `provider` | Dependency injection & `ChangeNotifierProvider` | Exposes `FastingController` to widget tree |
| `flutter_local_notifications` | Scheduled OS notifications | Android exact/inexact alarms & iOS UNUserNotificationCenter |
| `timezone` | `TZDateTime` scheduling for local notifications | Required by `flutter_local_notifications` |
| `intl` | Date, time, and duration formatting | Locale-aware date headers & timestamps |
| `share_plus` / `file_picker` | Exporting and importing backup `.json` files | Native OS share sheet & document picker |
| `sqflite_common_ffi` (dev) | Running SQLite unit tests on host machine | `dev_dependencies` only |

*(Record IDs are generated as 128-bit random hex strings using `dart:math` `Random.secure()`—no external `uuid` package needed.)*
