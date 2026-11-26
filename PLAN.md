# Fast O'Clock — Timeline & Performance Redesign Plan

Focused plan for upgrading Tab 2 (`TimelineScreen`) and decoupling 1 Hz timer rebuilds across the app, following full completion of the initial MVP and UI/UX feedback rounds.

---

## Stage 0 — Sync `/design` Docs & Plan Baseline
- [x] Sync `design/ARCHITECTURE.md` (actual tree, `clockTick`, `dynamic_color`, fonts, 15m eating-window alert, debug export).
- [x] Sync `design/DATA_MODEL.md` (4h minimum duration, 4 mood tags, 6 `MetabolicStage` thresholds, Timeline metrics & bucket math).
- [x] Sync `design/UI_SPEC.md` (`FastingScreen`, `SettingsScreen`, `FastEditorSheet`, and redesigned `TimelineScreen`).

---

## Stage 1 — Performance Foundation: Isolate 1 Hz Ticker + Day Rollover
- **`lib/state/fasting_controller.dart`**:
  - Expose `ValueListenable<DateTime> clockTick` (`ValueNotifier`) and dispose it in `dispose()`.
  - Compute `localDayKey` on demand (`year * 10000 + month * 100 + day`) and track `_lastNotifiedDayKey`.
  - `_syncTicker()` immediately refreshes `clockTick.value = nowUtc`; `_ticker` updates `clockTick` every 1s **without** `notifyListeners()`, calling `notifyListeners()` only when `localDayKey` changes at local midnight.
  - `didChangeAppLifecycleState(resumed)` refreshes `clockTick` and notifies if the local day rolled over.
  - Add monotonic `historyVersion` incremented on `_reloadRecords()`, and memoize legacy stats getters (`currentStreak`, `averageFastDuration`, `lastSevenDaysSummary`).
- **`lib/screens/fasting_screen.dart`**:
  - Wrap time-dependent active & idle UI in `ValueListenableBuilder<DateTime>(valueListenable: controller.clockTick)` reading live `controller.nowUtc` directly.
- **`lib/app.dart`**:
  - Replace `context.watch<FastingController>()` in `FastOClockApp.build` with `Selector` on `(isInitialized, isOnboarded, flutterThemeMode)` so `MaterialApp` performs 0 rebuilds/sec during active fasts.
  - Keep `_pages[_selectedIndex]` (no `IndexedStack`) and pass `onFocusedRecordHandled` to `TimelineScreen`.

---

## Stage 2 — Pure Timeline View-Model & Memoized Stats
- **`lib/models/timeline_summary.dart`**:
  - `TimelineRange` (`d7`, `d30`, `all`) and `TimelineFilter` (`all`, `goalMet`, `endedEarly`, `withNotes`).
  - Single-pass $O(N)$ `TimelineSnapshot.build(...)` computing:
    - Global all-time `currentStreak` and `bestStreak` (DST-safe day stepping).
    - Range-scoped KPIs (`totalFastsInRange`, `goalMetCountInRange`, `completionPercentInRange`, `averageDurationInRange`, `longestDurationInRange`).
    - Daily single-best-fast chart buckets (`7D`/`30D`, without summing multi-fast days) and up to 12 weekly-average buckets (`All`, `primaryRecord = null`).
    - Pre-formatted `TimelineMonthHeader` and `TimelineRecordItem` rows (date, duration, window, goal delta, `FastProtocol`, `MetabolicStage`, `progressRatio`, `semanticLabel`).

---

## Stage 3 — Single Interactive Bar Chart
- **`lib/widgets/timeline_chart.dart`**:
  - `DurationBarChart` rendered with a single `CustomPainter` inside `RepaintBoundary`.
  - Dashed horizontal reference line labeled `Default <Xh>`, unified `#00C853` / `#FF8A00` colors, tap-to-inspect readout pill (`Edit` on daily completed bars; read-only summary on `All` weekly / empty / active bars), and full `Semantics` summary.

---

## Stage 4 — Redesigned `TimelineScreen`
- **`lib/screens/timeline_screen.dart`**:
  - `StatefulWidget` watching only `(historyVersion, activeFast?.id, localDayKey, targetDurationMin)` via `Selector`.
  - Compact header (`Timeline` + `+ Log Fast` tonal button; no occluding extended FAB).
  - Range `SegmentedButton` (`7D` | `30D` | `All`), 2×2 KPI strip, `DurationBarChart`, horizontally scrollable filter chips (`All`, `Goal Met`, `Ended Early`, `Notes`), and empty-filter `"Show All"` state.
  - Flattened `SliverList.builder` with `PageStorageKey('timeline_scroll')`, month headers, compact rows (~96–112dp) with distinct mood icons/tints, and `focusedRecordId` jump + 1.2s highlight pulse.

---

## Stage 5 — Tests & Verification
- **`test/models/timeline_summary_test.dart`**: Global streak vs range KPIs, same-day multi-fast selection, mixed protocols, `All` weekly buckets, month headers, filters, deltas, metabolic stages.
- **`test/state/fasting_controller_test.dart`**: `clockTick` ticks without `notifyListeners()`, `_syncTicker()` refreshes immediately, midnight rollover notifies once, live `localDayKey`, `historyVersion`, `dispose()`.
- **`test/screens/timeline_screen_test.dart`**: Header & no FAB, range toggle, filter chips & empty-filter reset, distinct mood icons, 0 rebuilds during active fast ticks, `focusedRecordId` highlight.

---

## Validation Feedback — Round 2 (Implemented)
- [x] **Edge-to-Edge Full-Width Chart**:
  - Split `DurationBarChart` out of the padded KPI `Card` into its own full-bleed `SliverToBoxAdapter` (`0` horizontal outer padding, full width up to `640dp`) so bars span screen width and are easier to tap.
  - Overlay subtle Y-axis labels inside the left edge (`_leftGutter = 0`, `_rightPadding = 0`) and keep `16dp` horizontal padding only on the readout pill/legend below the bars.
  - Tighten header, KPI card, filter row, and list horizontal padding from `20dp` to `16dp`.
- [x] **Range-Scoped Filter Counts & History List (`7D` / `30D` / `All`)**:
  - Scope `allCount`, `goalMetCount`, `endedEarlyCount`, `withNotesCount`, and `items` (month headers + history cards) to the selected range (`7D` / `30D` / `All`) while keeping `currentStreak` and `bestStreak` global (all-time).
  - Show a `"Show All"` reset when range or filter matches 0 fasts, and auto-switch range to `TimelineRange.all` on `focusedRecordId` jump if target falls outside the active window.
- [x] **Fasting Record Row Date-Time Format**:
  - Revise each fasting record row's date-time display from `"Mon, Nov 23"` to match `FastingScreen`'s panel style (`MMM d • EEE` all-caps smaller) in the sequence `NOV 25 • WED • 12:11 PM`, where `NOV 25 • WED` is all-caps and smaller and `12:11 PM` is larger/bolder for readability.

---

## Phase 2 — Timeline Calendar, Spine, Editor Declutter & Bedtime (Planned)

### Stage 1 — Data Model, Settings & Migration (`v1` → `v2`)
- **`lib/models/fast_record.dart`**: Add `isClean` (`bool`, default `true`) and `endReason` (`String?`, nullable: `'hungry'`, `'social'`, `'unwell'`, `'other'`) with SQLite and backward-compatible JSON serialization.
- **`lib/services/database_service.dart`**: Bump `_dbVersion` to `2` with `onUpgrade` adding `is_clean INTEGER NOT NULL DEFAULT 1` and `end_reason TEXT`.
- **`lib/models/app_settings.dart` & `lib/services/preferences_service.dart`**: Add optional manual `bedtimeMinutesOfDay` (`int?`) with `clearBedtime = false` in `AppSettings.copyWith` (so clearing bedtime persists `null`), `SharedPreferences` persistence, and JSON backup serialization.
- **`lib/services/backup_service.dart`**: Bump `currentSchemaVersion = 2` and accept `schemaVersion` `1..2` on import so existing `v1` JSON backups restore seamlessly with defaults.
- **`lib/state/fasting_controller.dart`**: Update `endActiveFast`, `addPastFast`, `updateCompletedFast` for `isClean`/`endReason`; add `updateBedtime(int? minutesOfDay)`; update `_ensureStatsCache()` to read the 7-day `List<DayFastSummary>` helper without `TimelineRange`/`ChartBarBucket`.

### Stage 2 — Timeline View-Model & Month Calendar
- **`lib/models/timeline_summary.dart`**:
  - Replace bar-chart buckets and range/filter chip state with `CalendarDaySummary` (`goalMet`, `endedEarly`, `none`, `durationLabel`, `isToday`, `hasActiveFast`) for the visible month (daily-best-fast precedence: `goalMet` > `endedEarly`; active-only today shows outline ring + `"Active"`), while keeping a lightweight 7-day `List<DayFastSummary>` builder for `FastingController.lastSevenDaysSummary`.
  - Format `TimelineRecordItem` for the 3-line neutral card:
    - Line 1: `startDateLabel` (`NOV 25`), `weekdayLabel` (`WED`), `patternTag` (`14:10`, `16:8`, etc.).
    - Line 2: `baseDurationLabel` + optional `excessLabel` (`+2h 02m`) or `shortfallLabel` (`-3h 59m` strikeout) + explicit `Semantics` label spelling out goal/shortfall.
    - Line 3: plain `timeWindowLabel` (`12:11 PM – 4:15 AM`), `isLateNightStart` using modular minute distance `((startMin - bedtimeMin + 1440) % 1440) >= 1320 || <= 240` (handles post-midnight bedtimes), `isClean`, `endReasonLabel`.
- **`lib/widgets/timeline_calendar.dart`**:
  - Month calendar (`< Month YYYY >`, 7-column Mon–Sun grid) with Green (`#00C853`) = Goal Met, Orange (`#FF8A00`) = Ended Early, Blank = No record, Ring = Today/Active.
  - Tapping a day shows a compact tooltip chip (`16h 02m · Goal Met`, `Ended Early`, `Active`, or `No fast`).

### Stage 3 — `TimelineScreen`, `FastEditorSheet` & `SettingsScreen`
- **`lib/widgets/timeline_chart.dart` [DELETE]**: Remove orphaned `DurationBarChart` (593 lines) after migrating `goalMetColor` / `endedEarlyColor` constants.
- **`lib/screens/timeline_screen.dart`**:
  - Remove `7D | 30D | All` toggle, `DurationBarChart` + readout panel, `FilterChip` row, left colored card strip, colored metabolic-stage pill, and colored mood icons.
  - Compact 3-stat KPI strip (`Streak` | `Avg Duration` | `Goal Met %`), `TimelineCalendar`, and `SliverList.builder` with vertical timeline spine (`●──│` ... `▼`, newest first) and neutral cards (green/orange reserved strictly for `Goal Met` / `Ended Early` badge).
- **`lib/widgets/fast_editor_sheet.dart`**:
  - Replace bulky `Protocol` `ListTile` in `addPast`/`editPast` with compact target-hours chip row.
  - Add `Clean` | `Modified` toggle (default `Clean`) with calorie-deficit helper copy (*"Clean: 0 kcal · Modified: low-cal aid to sustain your calorie deficit"*).
  - Add conditional `Early-End Reason` chips (`Hungry`, `Social`, `Dizzy / Unwell`, `Other`) shown only when `actualDuration < targetDurationMin`.
  - Collapse `Optional Note` behind `+ Add note` when empty.
- **`lib/screens/fasting_screen.dart`**:
  - Update `FastEditorMode.completeActive` handler to pass `result.isClean` and `result.endReason` to `controller.endActiveFast(...)`.
  - Fix idle `"Your time to eat"` timer ring: when a prior fast exists, `<24h` pattern is selected, and `elapsedSinceLastFastEnded < eatingWindow`, display remaining eating window (`(24h - targetFastDuration) - elapsedSinceLastFastEnded`, e.g., `9h`), `Until: <time>` when window ends, and hide `Goal:`. When `history.isEmpty`, `targetDurationMin >= 1440`, or the eating window has ended (`remaining <= 0`), revert back to showing `Goal:`.
- **`lib/services/notification_service.dart` & `android/app/src/main/AndroidManifest.xml`**:
  - Fix non-firing scheduled notifications (`Fasting Goal Reached` & `Eating Window Ending`): add required `flutter_local_notifications` `ScheduledNotificationReceiver` / `ScheduledNotificationBootReceiver` + `RECEIVE_BOOT_COMPLETED` (and `SCHEDULE_EXACT_ALARM`) in `AndroidManifest.xml`, check `android.canScheduleExactNotifications()` with fallback to `AndroidScheduleMode.inexactAllowWhileIdle` (so Android 14+ never throws `exact_alarms_not_permitted`), log scheduling failures without failing `startFast`/`endActiveFast` DB writes, and ensure `requestPermissions()` is invoked before scheduling.
- **`lib/screens/settings_screen.dart`**: Add `Typical Bedtime` time picker (with clear option) under `Fasting Preferences`.

### Stage 4 — Tests & Verification
- Update `test/models/timeline_summary_test.dart`, `test/screens/timeline_screen_test.dart`, `test/screens/fasting_screen_test.dart` (idle eating-window ring + hidden `Goal:`), `test/state/fasting_controller_test.dart`, and `test/widgets/fast_editor_sheet_test.dart`.
- Add SQLite `v1` → `v2` upgrade and `BackupService` `v1`/`v2` JSON import tests (`test/services/database_service_test.dart`, `test/services/backup_service_test.dart`).

---

## Deferred (Future)
- **Midnight-Crossover Visualization** — visual component showing connection across midnight (start day 1 PM → end day 2 AM).
- **Optional Health Connect Sleep Sync (`READ_SLEEP`)** — automatic bedtime with manual fallback (see `design/PRIVACY_POLICY.md`).
- **Day-Based / Recurring Fasting Patterns** (ADF, 1 day/week, 5-day) — deferred pending streak calculation analysis.
- **Google Drive Backup** — deferred; focus on local file backup improvements first.
