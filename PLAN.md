# Fast-O-Clock — Fresh Flutter Native Plan

Simplified, ad-free, offline-first intermittent fasting tracker for personal and family use (inspired by *Fasting - Intermittent Fasting*).

---

## Pre-Flight TODO

- [ ] **Archive existing 3 prototype folders** into `_archive/` (or remove after confirming nothing needed):
  - `fast-o-clock-app/` (Framework7 + Svelte + Capacitor)
  - `fastoclock-flutter/` (old Flutter skeleton)
  - `fast-oclock/` (SvelteKit + Carbon + Capacitor)

---

## Scavenged Identity & Concepts

Preserved from the previous prototypes before cleanup:

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
/Volumes/Dev/lab/fast-o-clock/  # Root Flutter project (legacy prototypes in _archive/)
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

1. **Phase 0 — Archive & Bootstrap**
   - Move `fast-o-clock-app`, `fastoclock-flutter`, `fast-oclock` into `_archive/`.
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
